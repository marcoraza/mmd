#!/usr/bin/env python3
"""Valida capturas e exports do treinamento privado do MMD."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO_ROOT / "docs/training/delivery-manifest.json"
DEFAULT_MEDIA_ROOT = REPO_ROOT / "out/training"
OPERATIONAL_SCENES = {
    *(f"IOS-{number:02d}" for number in range(3, 11)),
    *(f"WEB-{number:02d}" for number in range(3, 10)),
}
PERSISTED_SCENES = {"IOS-06", "IOS-07", "IOS-08", "IOS-09"}
PLACEHOLDER_PATTERN = re.compile(r"\b(?:TODO|PENDENTE|PLACEHOLDER|SIMULA(?:C|Ç)[AÃ]O)\b", re.IGNORECASE)
TIMECODE_PATTERN = re.compile(r"(?:^|\n)\s*(?:#{1,6}\s*)?\[?\d{2}:\d{2}(?::\d{2})?\]?")
VTT_CUE_PATTERN = re.compile(r"\d{2}:\d{2}(?::\d{2})?\.\d{3}\s+-->\s+\d{2}:\d{2}(?::\d{2})?\.\d{3}")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file_handle:
        for chunk in iter(lambda: file_handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as file_handle:
        data = json.load(file_handle)
    if not isinstance(data, dict):
        raise ValueError("O manifest precisa ser um objeto JSON.")
    return data


def probe_media(path: Path) -> dict[str, Any]:
    process = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration:stream=codec_type,codec_name,width,height",
            "-of",
            "json",
            str(path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if process.returncode != 0:
        raise ValueError(process.stderr.strip() or "ffprobe não conseguiu ler o arquivo")
    return json.loads(process.stdout)


def measure_audio_peak(path: Path) -> float:
    process = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
        check=False,
        capture_output=True,
        text=True,
    )
    match = re.search(r"max_volume:\s*(-?(?:inf|\d+(?:\.\d+)?))\s*dB", process.stderr)
    if process.returncode != 0 or match is None:
        raise ValueError("ffmpeg não conseguiu medir o pico de áudio")
    value = match.group(1)
    return float("-inf") if value == "-inf" else float(value)


def _path_for(media_root: Path, value: Any) -> Path | None:
    if not isinstance(value, str) or not value.strip():
        return None
    return media_root / value


def validate_capture_records(manifest: dict[str, Any], media_root: Path) -> list[str]:
    errors: list[str] = []
    records = manifest.get("captures")
    if not isinstance(records, list):
        return ["captures precisa ser uma lista."]

    expected = {
        ("INS-03", "IOS"),
        ("INS-04", "IOS"),
        ("INS-05", "IOS"),
        ("IOS-01", "IOS"),
        ("IOS-01", "CAM"),
        *( (f"IOS-{number:02d}", "IOS") for number in range(2, 12) ),
        *( (f"WEB-{number:02d}", "WEB") for number in range(1, 10) ),
    }
    indexed: dict[tuple[str, str], dict[str, Any]] = {}
    for record in records:
        if not isinstance(record, dict):
            errors.append("Cada captura precisa ser um objeto.")
            continue
        key = (str(record.get("scene", "")), str(record.get("source", "")))
        if key in indexed:
            errors.append(f"Captura duplicada: {key[0]} {key[1]}.")
        indexed[key] = record

    for scene, source in sorted(expected):
        record = indexed.get((scene, source))
        label = f"{scene} {source}"
        if record is None:
            errors.append(f"Captura obrigatória ausente: {label}.")
            continue
        if record.get("status") != "approved":
            errors.append(f"{label}: status precisa ser approved.")
        if record.get("provenance") != "real":
            errors.append(f"{label}: provenance precisa ser real.")
        if record.get("privacy") != "approved":
            errors.append(f"{label}: revisão de privacidade pendente.")

        media_path = _path_for(media_root, record.get("path"))
        if media_path is None:
            errors.append(f"{label}: arquivo não informado.")
        elif not media_path.is_file() or media_path.stat().st_size == 0:
            errors.append(f"{label}: arquivo ausente ou vazio: {media_path}.")
        else:
            expected_hash = record.get("sha256")
            if not isinstance(expected_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
                errors.append(f"{label}: sha256 inválido.")
            elif sha256_file(media_path) != expected_hash:
                errors.append(f"{label}: sha256 não confere.")

        notes = str(record.get("notes", ""))
        if PLACEHOLDER_PATTERN.search(notes) or PLACEHOLDER_PATTERN.search(str(record.get("path", ""))):
            errors.append(f"{label}: captura simulada ou pendente não pode servir como evidência.")
        if scene in OPERATIONAL_SCENES and not re.fullmatch(r"TRN-MARCELO-\d{2}", str(record.get("eventCode", ""))):
            errors.append(f"{label}: eventCode exclusivo do treinamento não comprovado.")

    hardware_record = indexed.get(("IOS-01", "CAM"), {})
    if hardware_record.get("hardware") != "Zebra RFD40":
        errors.append("IOS-01 CAM: hardware precisa ser Zebra RFD40.")
    tag_record = indexed.get(("IOS-05", "IOS"), {})
    if not isinstance(tag_record.get("tagCount"), int) or tag_record.get("tagCount", 0) < 5:
        errors.append("IOS-05 IOS: são necessárias pelo menos 5 tags reais.")
    if tag_record.get("knownTag") is not True or tag_record.get("unknownTag") is not True:
        errors.append("IOS-05 IOS: a leitura precisa incluir tag conhecida e desconhecida.")
    if indexed.get(("IOS-10", "IOS"), {}).get("qrFallback") is not True:
        errors.append("IOS-10 IOS: fallback por QR não comprovado.")
    for scene in sorted(PERSISTED_SCENES):
        if indexed.get((scene, "IOS"), {}).get("persisted") is not True:
            errors.append(f"{scene} IOS: persistência real não comprovada.")
    return errors


def validate_outputs(
    manifest: dict[str, Any],
    media_root: Path,
    probe: Callable[[Path], dict[str, Any]] = probe_media,
    audio_peak: Callable[[Path], float] = measure_audio_peak,
) -> list[str]:
    errors: list[str] = []
    outputs = manifest.get("outputs")
    if not isinstance(outputs, list) or len(outputs) != 4:
        return ["outputs precisa declarar exatamente os quatro exports finais."]

    expected_names = {"master", "web", "ios", "ios-vertical"}
    actual_names = {str(output.get("name", "")) for output in outputs if isinstance(output, dict)}
    if actual_names != expected_names:
        errors.append("Exports obrigatórios: master, web, ios e ios-vertical.")

    for output in outputs:
        if not isinstance(output, dict):
            errors.append("Cada export precisa ser um objeto.")
            continue
        name = str(output.get("name", "sem-nome"))
        media_path = _path_for(media_root, output.get("path"))
        if media_path is None or not media_path.is_file() or media_path.stat().st_size == 0:
            errors.append(f"{name}: vídeo final ausente ou vazio.")
            continue
        try:
            media = probe(media_path)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            errors.append(f"{name}: mídia inválida: {error}.")
            continue

        streams = media.get("streams", [])
        video_streams = [stream for stream in streams if stream.get("codec_type") == "video"]
        audio_streams = [stream for stream in streams if stream.get("codec_type") == "audio"]
        if not video_streams or not audio_streams:
            errors.append(f"{name}: vídeo e áudio são obrigatórios.")
        else:
            video = video_streams[0]
            expected_width = output.get("width")
            expected_height = output.get("height")
            if video.get("width") != expected_width or video.get("height") != expected_height:
                errors.append(f"{name}: resolução precisa ser {expected_width}x{expected_height}.")
            if video.get("codec_name") != "h264" or audio_streams[0].get("codec_name") != "aac":
                errors.append(f"{name}: codecs precisam ser H.264 e AAC.")

        try:
            duration = float(media.get("format", {}).get("duration", 0))
        except (TypeError, ValueError):
            duration = 0
        if not float(output.get("minDurationSeconds", 0)) <= duration <= float(output.get("maxDurationSeconds", 0)):
            errors.append(f"{name}: duração fora do intervalo aprovado.")
        try:
            if audio_peak(media_path) > -1.0:
                errors.append(f"{name}: pico de áudio acima de -1 dBFS.")
        except (OSError, ValueError) as error:
            errors.append(f"{name}: pico de áudio não validado: {error}.")

        companions = (
            ("subtitles", "VTT"),
            ("transcript", "transcript"),
            ("timecodes", "timecodes"),
            ("thumbnail", "thumbnail"),
        )
        for field, label in companions:
            companion = _path_for(media_root, output.get(field))
            if companion is None or not companion.is_file() or companion.stat().st_size == 0:
                errors.append(f"{name}: {label} ausente ou vazio.")
                continue
            if field == "thumbnail":
                continue
            content = companion.read_text(encoding="utf-8")
            if PLACEHOLDER_PATTERN.search(content):
                errors.append(f"{name}: {label} ainda contém placeholder.")
            if field == "subtitles" and (not content.startswith("WEBVTT") or not VTT_CUE_PATTERN.search(content)):
                errors.append(f"{name}: VTT sem cabeçalho ou cue válido.")
            if field == "timecodes" and not TIMECODE_PATTERN.search(content):
                errors.append(f"{name}: arquivo sem timecode reconhecível.")
            if field == "transcript" and len(content.strip()) < 200:
                errors.append(f"{name}: transcript curto demais para o export.")
        if output.get("privacy") != "approved":
            errors.append(f"{name}: revisão final de privacidade pendente.")
    return errors


def validate_delivery(
    manifest: dict[str, Any],
    media_root: Path,
    probe: Callable[[Path], dict[str, Any]] = probe_media,
    audio_peak: Callable[[Path], float] = measure_audio_peak,
) -> list[str]:
    errors: list[str] = []
    if manifest.get("eventName") != "Treinamento · Marcelo":
        errors.append("eventName precisa ser Treinamento · Marcelo.")
    errors.extend(validate_capture_records(manifest, media_root))
    errors.extend(validate_outputs(manifest, media_root, probe, audio_peak))
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Valida a entrega audiovisual do treinamento MMD.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--media-root", type=Path, default=DEFAULT_MEDIA_ROOT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest = load_manifest(args.manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Manifest inválido: {error}", file=sys.stderr)
        return 2
    errors = validate_delivery(manifest, args.media_root)
    if errors:
        print(f"Entrega incompleta: {len(errors)} blocker(s).")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Entrega audiovisual validada: capturas reais e quatro exports aprovados.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
