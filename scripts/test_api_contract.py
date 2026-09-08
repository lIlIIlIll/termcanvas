#!/usr/bin/env python3

import json
import tempfile
import unittest
from pathlib import Path

import api_contract
import validate_architecture


class ApiContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        source = self.root / "packages/sample/src"
        source.mkdir(parents=True)
        (source / "api.cj").write_text(
            """package sample

public class StableType {
    public func value(): Int64 { 1 }
    public func diagnostic(): Int64 { 2 }
    public func runtimeState(): InternalType { InternalType() }
}

public enum StableEvent<T> {
    // A pipe in a comment is not a constructor: | Hidden
    | Plain | SameLine(Int64)
    | Payload(Array<T>, sample.ExperimentalType)
    | Multiline(
        Array<ExperimentalType>,
        (String) -> StableType
    )
}

public class ExperimentalType {}
public class InternalType {}
""",
            encoding="utf-8",
        )
        (source / "api_test.cj").write_text(
            """package sample
public class PublicTestFixture {
    public func helper(): Unit {}
}
""",
            encoding="utf-8",
        )
        self.metadata = {
            "source_roots": ["packages/sample/src"],
            "excluded_paths": ["packages/*/src/*_test.cj"],
            "rules": [
                self.rule("stable", "StableType", "STABLE"),
                {
                    **self.rule("stable-diagnostic", "StableType", "EXPERIMENTAL"),
                    "match": {"package": "sample", "qualified_symbols": ["StableType.diagnostic"]},
                },
                {
                    **self.rule("stable-runtime", "StableType", "INTERNAL"),
                    "match": {"package": "sample", "qualified_symbols": ["StableType.runtimeState"]},
                },
                self.rule("stable-event", "StableEvent", "STABLE"),
                self.rule("experimental", "ExperimentalType", "EXPERIMENTAL"),
                self.rule("internal", "InternalType", "INTERNAL"),
            ],
        }

    def tearDown(self):
        self.temp.cleanup()

    @staticmethod
    def rule(rule_id, symbol, stability):
        rule = {
            "id": rule_id,
            "match": {"package": "sample", "symbols": [symbol]},
            "stability": stability,
            "subsystem": "fixture",
            "owner": "fixture",
            "reason": "fixture classification",
            "consumer_evidence": "fixture",
        }
        if stability == "EXPERIMENTAL":
            rule["promotion_condition"] = "fixture promotion"
            rule["sunset_condition"] = "fixture sunset"
        return rule

    def records(self):
        return api_contract.classify(api_contract.extract(self.metadata, self.root), self.metadata)

    def test_production_public_type_and_member_are_included(self):
        qualified = {record["qualified_symbol"] for record in self.records()}
        self.assertIn("StableType", qualified)
        self.assertIn("StableType.value", qualified)

    def test_test_source_public_helper_is_excluded_by_path(self):
        qualified = {record["qualified_symbol"] for record in self.records()}
        self.assertNotIn("PublicTestFixture", qualified)
        self.assertEqual(api_contract.excluded_test_declaration_count(self.metadata, self.root), 2)

    def test_production_symbols_receive_distinct_tiers(self):
        tiers = {
            record["owner_symbol"]: record["stability"]
            for record in self.records() if record["level"] == "top_level"
        }
        self.assertEqual(tiers["StableType"], "STABLE")
        self.assertEqual(tiers["ExperimentalType"], "EXPERIMENTAL")
        self.assertEqual(tiers["InternalType"], "INTERNAL")

    def test_qualified_member_rules_override_a_stable_owner_type(self):
        tiers = {record["qualified_symbol"]: record["stability"] for record in self.records()}
        self.assertEqual(tiers["StableType"], "STABLE")
        self.assertEqual(tiers["StableType.value"], "STABLE")
        self.assertEqual(tiers["StableType.diagnostic"], "EXPERIMENTAL")
        self.assertEqual(tiers["StableType.runtimeState"], "INTERNAL")

    def test_enum_constructors_are_inventory_members_and_inherit_stability(self):
        cases = {
            record["qualified_symbol"]: record
            for record in self.records() if record["level"] == "enum_constructor"
        }
        self.assertEqual(
            set(cases),
            {
                "StableEvent.Plain",
                "StableEvent.SameLine",
                "StableEvent.Payload",
                "StableEvent.Multiline",
            },
        )
        self.assertTrue(all(record["stability"] == "STABLE" for record in cases.values()))
        self.assertEqual(cases["StableEvent.Plain"]["signature"], "Plain")
        self.assertEqual(cases["StableEvent.SameLine"]["signature"], "SameLine(Int64)")
        ordered = [
            record["qualified_symbol"] for record in self.records()
            if record["level"] == "enum_constructor"
        ]
        self.assertLess(ordered.index("StableEvent.Plain"), ordered.index("StableEvent.SameLine"))
        self.assertEqual(
            cases["StableEvent.Multiline"]["signature"],
            "Multiline( Array<ExperimentalType>, (String) -> StableType )",
        )

    def test_enum_constructor_removal_changes_the_stable_contract(self):
        before = {
            api_contract.classified_contract_line(record)
            for record in self.records() if record["stability"] == "STABLE"
        }
        source = self.root / "packages/sample/src/api.cj"
        source.write_text(
            source.read_text(encoding="utf-8").replace("    | Plain | SameLine(Int64)\n", "    | Plain\n"),
            encoding="utf-8",
        )
        after = {
            api_contract.classified_contract_line(record)
            for record in self.records() if record["stability"] == "STABLE"
        }
        self.assertIn("sample|StableEvent.SameLine|enum_constructor|SameLine(Int64)", before)
        self.assertNotEqual(before, after)

    def test_stable_enum_payload_dependency_is_visible(self):
        edges = validate_architecture.dependency_edges(self.records())
        self.assertIn(
            ("sample.StableEvent.Payload", "sample.ExperimentalType", "EXPERIMENTAL"),
            edges,
        )
        self.assertIn(
            ("sample.StableEvent.Multiline", "sample.ExperimentalType", "EXPERIMENTAL"),
            edges,
        )

    def test_unclassified_production_public_symbol_is_an_error(self):
        (self.root / "packages/sample/src/api.cj").write_text(
            (self.root / "packages/sample/src/api.cj").read_text(encoding="utf-8")
            + "\npublic class NewUnclassifiedType {}\n",
            encoding="utf-8",
        )
        records = self.records()
        errors = api_contract.validate_metadata(records, self.metadata)
        self.assertTrue(any("NewUnclassifiedType" in error for error in errors))


class GovernanceVisibilityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / "packages/sample/src/api.cj"
        self.source.parent.mkdir(parents=True)
        self.metadata = {
            "source_roots": ["packages/sample/src"],
            "excluded_paths": [],
            "rules": [],
        }

    def tearDown(self):
        self.temp.cleanup()

    def records(self, source):
        self.source.write_text("package sample\n\n" + source, encoding="utf-8")
        return api_contract.extract(self.metadata, self.root)

    def test_implicit_interface_members_are_public_contract_entries(self):
        records = self.records(
            """public interface Foo {
    func bar(): Unit
    func baz(): Unit
}
"""
        )
        members = {record["qualified_symbol"]: record for record in records}
        self.assertIn("Foo.bar", members)
        self.assertIn("Foo.baz", members)
        self.assertEqual(members["Foo.bar"]["visibility"], "public")
        self.assertEqual(members["Foo.bar"]["visibility_origin"], "interface")
        self.assertEqual(members["Foo.bar"]["member_kind"], "interface_member")

    def test_explicit_public_interface_member_is_not_duplicated(self):
        records = self.records(
            """public interface Foo {
    public func bar(): Unit
}
"""
        )
        bars = [record for record in records if record["qualified_symbol"] == "Foo.bar"]
        self.assertEqual(len(bars), 1)
        self.assertEqual(bars[0]["visibility_origin"], "explicit")
        self.assertEqual(bars[0]["member_kind"], "interface_member")

    def test_nested_public_owner_uses_qualified_lexical_scope(self):
        records = self.records(
            """public class A {
    public class B {
        public func method(): Unit {}
    }
}
"""
        )
        by_name = {record["qualified_symbol"]: record for record in records}
        self.assertIn("A.B", by_name)
        self.assertIn("A.B.method", by_name)
        self.assertEqual(by_name["A.B.method"]["owner_symbol"], "A")

    def test_nonpublic_type_after_public_owner_does_not_inherit_owner(self):
        records = self.records(
            """public class Snapshot {
}

internal class ExternalWakeSource {
    public func drain(): Unit {}
}
"""
        )
        qualified = {record["qualified_symbol"] for record in records}
        self.assertIn("Snapshot", qualified)
        self.assertNotIn("Snapshot.drain", qualified)
        self.assertNotIn("ExternalWakeSource.drain", qualified)

    def test_conditional_nonpublic_implementations_have_independent_scopes(self):
        records = self.records(
            """@When[os == "PlatformX"]
internal class ImplX {
    public func drain(): Unit {}
}

@When[os == "PlatformY"]
internal class ImplY {
    public func drain(): Unit {}
}
"""
        )
        self.assertEqual(records, [])

    def test_interface_implementation_does_not_pollute_interface_owner(self):
        records = self.records(
            """public interface Sink {
    func onEvent(): Unit
}

internal class Impl <: Sink {
    public func onEvent(): Unit {}
}
"""
        )
        events = [record for record in records if record["qualified_symbol"] == "Sink.onEvent"]
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["visibility_origin"], "interface")
        self.assertFalse(any(record["qualified_symbol"] == "Impl.onEvent" for record in records))

    def test_block_comments_do_not_create_public_declarations(self):
        records = self.records(
            """public class Visible {
    /*
     * Example text can contain a declaration-shaped line:
    public func ghostMember(): Unit {}
    /* nested example: public func nestedGhost(): Unit {} */
     */
    public func realMember(): Unit {}
}

/*
public class GhostType {
    public func ghost(): Unit {}
}
*/
"""
        )
        qualified = {record["qualified_symbol"] for record in records}
        self.assertEqual(qualified, {"Visible", "Visible.realMember"})

    def test_unicode_line_separators_inside_comments_keep_physical_lines_aligned(self):
        records = self.records(
            "/* doc\u2028continued\u2029public func ghost(): Unit {} */\n"
            "public func visible(): Unit {}\n"
        )
        self.assertEqual(
            [(record["qualified_symbol"], record["line"]) for record in records],
            [("visible", 4)],
        )

    def test_unicode_line_separators_inside_literals_keep_physical_lines_aligned(self):
        records = self.records(
            'let example = "public func ghost(): Unit {}\u2028continued\u2029"\n'
            "public func visible(): Unit {}\n"
        )
        self.assertEqual(
            [(record["qualified_symbol"], record["line"]) for record in records],
            [("visible", 4)],
        )


if __name__ == "__main__":
    unittest.main()
