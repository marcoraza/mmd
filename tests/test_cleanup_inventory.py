import importlib.util
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def load_module(relative_path: str, module_name: str):
    module_path = REPO_ROOT / relative_path
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


class CleanupInventoryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module("scripts/cleanup_inventory.py", "cleanup_inventory_test")

    def test_extensor_ac_goes_to_energia(self):
        warnings = []
        categoria = self.module.resolve_category(
            raw_category="EXTENSOR",
            raw_subcategory="EXTENSOR AC",
            brand="",
            model="CABO EXTENSOR AC 1M",
            notes="",
            warnings=warnings,
            source_ref="TEST:1",
        )

        self.assertEqual(categoria, "ENERGIA")
        self.assertTrue(any("Categoria ambigua EXTENSOR" in warning for warning in warnings))

    def test_blank_category_uses_context(self):
        warnings = []
        categoria = self.module.resolve_category(
            raw_category="",
            raw_subcategory="microfone",
            brand="Sennheiser",
            model="EWD SKM-S",
            notes="",
            warnings=warnings,
            source_ref="TEST:2",
        )

        self.assertEqual(categoria, "AUDIO")
        self.assertTrue(any("Categoria ambigua ''" in warning for warning in warnings))

    def test_digit_token_compatibility_blocks_wrong_model_match(self):
        self.assertFalse(self.module.digit_token_compatible("yamaha mg10xu", "yamaha mg16xu"))
        self.assertTrue(self.module.digit_token_compatible("asus x512fb", "asus x512f"))
        self.assertTrue(self.module.digit_token_compatible("showtech st x251layx2", "st x251lay"))

    def test_lot_length_bucket_uses_coarse_ranges(self):
        self.assertEqual(
            self.module.lot_length_bucket({"modelo": "XLR XLR 1 METRO", "raw_subcategory": "XLR"}),
            "CURTO",
        )
        self.assertEqual(
            self.module.lot_length_bucket({"modelo": "CABO HDMI 3M", "raw_subcategory": "HDMI"}),
            "MEDIO",
        )
        self.assertEqual(
            self.module.lot_length_bucket({"modelo": "CABO SPEAK ON 12M", "raw_subcategory": "SPEAK ON"}),
            "LONGO",
        )

    def test_condition_defaults_match_formula(self):
        estado, desgaste, depreciacao_pct, valor_atual = self.module.compute_condition(1000.0)

        self.assertEqual(estado, "USADO")
        self.assertEqual(desgaste, 3)
        self.assertEqual(depreciacao_pct, 39.0)
        self.assertEqual(valor_atual, 390.0)


if __name__ == "__main__":
    unittest.main()
