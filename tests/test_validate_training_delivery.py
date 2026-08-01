import hashlib
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "scripts/validate-training-delivery.py"
SPEC = importlib.util.spec_from_file_location("validate_training_delivery", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def complete_captures(media_root: Path) -> list[dict]:
    keys = [
        ("INS-03", "IOS"),
        ("INS-04", "IOS"),
        ("INS-05", "IOS"),
        ("IOS-01", "IOS"),
        ("IOS-01", "CAM"),
        *((f"IOS-{number:02d}", "IOS") for number in range(2, 12)),
        *((f"WEB-{number:02d}", "WEB") for number in range(1, 10)),
    ]
    records = []
    for scene, source in keys:
        relative_path = Path("raw") / f"{scene}-{source}.mov"
        absolute_path = media_root / relative_path
        absolute_path.parent.mkdir(parents=True, exist_ok=True)
        absolute_path.write_bytes(f"real take {scene} {source}".encode())
        record = {
            "scene": scene,
            "source": source,
            "path": str(relative_path),
            "status": "approved",
            "provenance": "real",
            "privacy": "approved",
            "sha256": file_hash(absolute_path),
        }
        if scene in MODULE.OPERATIONAL_SCENES:
            record["eventCode"] = "TRN-MARCELO-01"
        records.append(record)

    by_key = {(record["scene"], record["source"]): record for record in records}
    by_key[("IOS-01", "CAM")]["hardware"] = "Zebra RFD40"
    by_key[("IOS-05", "IOS")].update({"tagCount": 5, "knownTag": True, "unknownTag": True})
    by_key[("IOS-10", "IOS")]["qrFallback"] = True
    for scene in MODULE.PERSISTED_SCENES:
        by_key[(scene, "IOS")]["persisted"] = True
    return records


def complete_outputs(media_root: Path) -> list[dict]:
    specs = [
        ("master", 1920, 1080, 1500, 2100, 1800),
        ("web", 1920, 1080, 600, 900, 720),
        ("ios", 1920, 1080, 720, 1080, 900),
        ("ios-vertical", 1080, 1920, 720, 1080, 900),
    ]
    outputs = []
    final_dir = media_root / "final"
    final_dir.mkdir(parents=True, exist_ok=True)
    for name, width, height, minimum, maximum, duration in specs:
        base = f"mmd-{name}"
        paths = {
            "path": f"final/{base}.mp4",
            "subtitles": f"final/{base}.vtt",
            "transcript": f"final/{base}.transcript.md",
            "timecodes": f"final/{base}.timecodes.md",
            "thumbnail": f"final/{base}.thumbnail.jpg",
        }
        (media_root / paths["path"]).write_bytes(b"video")
        (media_root / paths["subtitles"]).write_text(
            "WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nTreinamento MMD\n",
            encoding="utf-8",
        )
        (media_root / paths["transcript"]).write_text("Treinamento MMD. " * 20, encoding="utf-8")
        (media_root / paths["timecodes"]).write_text("00:00 Abertura\n00:10 Operação\n", encoding="utf-8")
        (media_root / paths["thumbnail"]).write_bytes(b"thumbnail")
        outputs.append(
            {
                "name": name,
                **paths,
                "width": width,
                "height": height,
                "minDurationSeconds": minimum,
                "maxDurationSeconds": maximum,
                "testDuration": duration,
                "privacy": "approved",
            }
        )
    return outputs


class TrainingDeliveryValidationTest(unittest.TestCase):
    def test_accepts_real_capture_set_with_hashes_and_physical_proof(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            media_root = Path(temp_dir)
            manifest = {"captures": complete_captures(media_root)}

            self.assertEqual(MODULE.validate_capture_records(manifest, media_root), [])

    def test_rejects_mock_as_physical_evidence(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            media_root = Path(temp_dir)
            records = complete_captures(media_root)
            records[0]["provenance"] = "mock"
            records[0]["notes"] = "simulação para ensaio"

            errors = MODULE.validate_capture_records({"captures": records}, media_root)

            self.assertTrue(any("provenance precisa ser real" in error for error in errors))
            self.assertTrue(any("simulada ou pendente" in error for error in errors))

    def test_rejects_less_than_five_tags_or_missing_unknown_tag(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            media_root = Path(temp_dir)
            records = complete_captures(media_root)
            target = next(record for record in records if record["scene"] == "IOS-05")
            target["tagCount"] = 4
            target["unknownTag"] = False

            errors = MODULE.validate_capture_records({"captures": records}, media_root)

            self.assertTrue(any("pelo menos 5 tags reais" in error for error in errors))
            self.assertTrue(any("tag conhecida e desconhecida" in error for error in errors))

    def test_accepts_four_exports_with_audio_subtitles_and_companions(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            media_root = Path(temp_dir)
            outputs = complete_outputs(media_root)
            durations = {str(media_root / output["path"]): output["testDuration"] for output in outputs}

            def probe(path: Path):
                output = next(item for item in outputs if media_root / item["path"] == path)
                return {
                    "format": {"duration": str(durations[str(path)])},
                    "streams": [
                        {"codec_type": "video", "codec_name": "h264", "width": output["width"], "height": output["height"]},
                        {"codec_type": "audio", "codec_name": "aac"},
                    ],
                }

            errors = MODULE.validate_outputs({"outputs": outputs}, media_root, probe, lambda _: -2.0)

            self.assertEqual(errors, [])

    def test_rejects_clipping_and_wrong_vertical_resolution(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            media_root = Path(temp_dir)
            outputs = complete_outputs(media_root)

            def probe(path: Path):
                output = next(item for item in outputs if media_root / item["path"] == path)
                width = 1920 if output["name"] == "ios-vertical" else output["width"]
                return {
                    "format": {"duration": str(output["testDuration"])},
                    "streams": [
                        {"codec_type": "video", "codec_name": "h264", "width": width, "height": output["height"]},
                        {"codec_type": "audio", "codec_name": "aac"},
                    ],
                }

            errors = MODULE.validate_outputs({"outputs": outputs}, media_root, probe, lambda _: 0.0)

            self.assertTrue(any("ios-vertical: resolução" in error for error in errors))
            self.assertEqual(sum("pico de áudio" in error for error in errors), 4)


if __name__ == "__main__":
    unittest.main()
