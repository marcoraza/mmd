#!/usr/bin/env python3
"""Add MMDEstoqueTests unit test target to the Xcode project."""

import hashlib
import re

PBXPROJ = "apps/ios/MMDEstoque/MMDEstoque.xcodeproj/project.pbxproj"

# Test files
TEST_FILES = [
    "EquipmentTests.swift",
    "SerialNumberTests.swift",
    "RFIDManagerTests.swift",
    "APIClientTests.swift",
    "ThemeTests.swift",
]

def make_uuid(seed: str) -> str:
    """Generate a deterministic 24-char hex UUID from a seed string."""
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()

# Generate all needed UUIDs
uuids = {}
for f in TEST_FILES:
    uuids[f"fileref_{f}"] = make_uuid(f"test_fileref_{f}")
    uuids[f"buildfile_{f}"] = make_uuid(f"test_buildfile_{f}")

uuids["test_group"] = make_uuid("MMDEstoqueTests_group")
uuids["test_product"] = make_uuid("MMDEstoqueTests_product")
uuids["test_target"] = make_uuid("MMDEstoqueTests_target")
uuids["test_sources_phase"] = make_uuid("MMDEstoqueTests_sources")
uuids["test_frameworks_phase"] = make_uuid("MMDEstoqueTests_frameworks")
uuids["container_proxy"] = make_uuid("MMDEstoqueTests_proxy")
uuids["target_dependency"] = make_uuid("MMDEstoqueTests_dependency")
uuids["debug_config"] = make_uuid("MMDEstoqueTests_debug_config")
uuids["release_config"] = make_uuid("MMDEstoqueTests_release_config")
uuids["config_list"] = make_uuid("MMDEstoqueTests_config_list")

# Main target UUID (from existing pbxproj)
MAIN_TARGET = "E70DBF9CCB294761263BA41F"
MAIN_PRODUCT = "CEC1B1C61CA46E5ACBEF44A2"
ROOT_OBJECT = "F8B248B3A459F5E71C7A64F9"
PRODUCTS_GROUP = "A554FE26975DA894A371472E"
MAIN_GROUP = "F6E431623D6F51DE352F6B3F"

with open(PBXPROJ, "r") as f:
    content = f.read()

# 1. Add PBXBuildFile entries for test files
build_file_entries = []
for tf in TEST_FILES:
    bf_uuid = uuids[f"buildfile_{tf}"]
    fr_uuid = uuids[f"fileref_{tf}"]
    build_file_entries.append(
        f"\t\t{bf_uuid} /* {tf} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_uuid} /* {tf} */; }};"
    )

content = content.replace(
    "/* End PBXBuildFile section */",
    "\n".join(build_file_entries) + "\n/* End PBXBuildFile section */"
)

# 2. Add PBXContainerItemProxy
proxy_section = f"""/* Begin PBXContainerItemProxy section */
\t\t{uuids['container_proxy']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {ROOT_OBJECT} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {MAIN_TARGET};
\t\t\tremoteInfo = MMDEstoque;
\t\t}};
/* End PBXContainerItemProxy section */

"""
content = content.replace(
    "/* Begin PBXFileReference section */",
    proxy_section + "/* Begin PBXFileReference section */"
)

# 3. Add PBXFileReference entries for test files + test product
file_ref_entries = []
for tf in TEST_FILES:
    fr_uuid = uuids[f"fileref_{tf}"]
    file_ref_entries.append(
        f'\t\t{fr_uuid} /* {tf} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {tf}; sourceTree = "<group>"; }};'
    )
# Test bundle product
file_ref_entries.append(
    f'\t\t{uuids["test_product"]} /* MMDEstoqueTests.xctest */ = {{isa = PBXFileReference; includeInIndex = 0; lastKnownFileType = wrapper.cfbundle; path = MMDEstoqueTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};'
)

content = content.replace(
    "/* End PBXFileReference section */",
    "\n".join(file_ref_entries) + "\n/* End PBXFileReference section */"
)

# 4. Add PBXFrameworksBuildPhase for tests
frameworks_entry = f"""\t\t{uuids['test_frameworks_phase']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""

content = content.replace(
    "/* End PBXFrameworksBuildPhase section */",
    frameworks_entry + "\n/* End PBXFrameworksBuildPhase section */"
)

# 5. Add PBXGroup for MMDEstoqueTests
children_str = ",\n".join(
    f'\t\t\t\t{uuids[f"fileref_{tf}"]} /* {tf} */' for tf in TEST_FILES
)
test_group = f"""\t\t{uuids['test_group']} /* MMDEstoqueTests */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children_str},
\t\t\t);
\t\t\tpath = MMDEstoqueTests;
\t\t\tsourceTree = "<group>";
\t\t}};"""

content = content.replace(
    "/* End PBXGroup section */",
    test_group + "\n/* End PBXGroup section */"
)

# 6. Add test product to Products group
content = content.replace(
    f"{MAIN_PRODUCT} /* MMDEstoque.app */,\n\t\t\t);\n\t\t\tname = Products;",
    f"{MAIN_PRODUCT} /* MMDEstoque.app */,\n\t\t\t\t{uuids['test_product']} /* MMDEstoqueTests.xctest */,\n\t\t\t);\n\t\t\tname = Products;"
)

# 7. Add MMDEstoqueTests group to main group
content = content.replace(
    f"{uuids['test_group']}",  # Temporary - need to add to main group children
    uuids['test_group']
)
# Add test group to the main group's children
content = content.replace(
    f'859180E7DC8F066DC34DB293 /* MMDEstoque */,\n\t\t\t\t68A8EA788B6444E5FA936405 /* Frameworks */',
    f'859180E7DC8F066DC34DB293 /* MMDEstoque */,\n\t\t\t\t{uuids["test_group"]} /* MMDEstoqueTests */,\n\t\t\t\t68A8EA788B6444E5FA936405 /* Frameworks */',
)

# 8. Add PBXNativeTarget for tests + PBXTargetDependency
target_dep_section = f"""/* Begin PBXTargetDependency section */
\t\t{uuids['target_dependency']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {MAIN_TARGET} /* MMDEstoque */;
\t\t\ttargetProxy = {uuids['container_proxy']} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

"""

test_target = f"""\t\t{uuids['test_target']} /* MMDEstoqueTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {uuids['config_list']} /* Build configuration list for PBXNativeTarget "MMDEstoqueTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{uuids['test_sources_phase']} /* Sources */,
\t\t\t\t{uuids['test_frameworks_phase']} /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{uuids['target_dependency']} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = MMDEstoqueTests;
\t\t\tproductName = MMDEstoqueTests;
\t\t\tproductReference = {uuids['test_product']} /* MMDEstoqueTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};"""

content = content.replace(
    "/* End PBXNativeTarget section */",
    test_target + "\n/* End PBXNativeTarget section */\n\n" + target_dep_section
)

# 9. Add test target to project targets list
content = content.replace(
    f"{MAIN_TARGET} /* MMDEstoque */,\n\t\t\t\t);\n\t\t\t}};\n/* End PBXProject section */",
    f"{MAIN_TARGET} /* MMDEstoque */,\n\t\t\t\t\t{uuids['test_target']} /* MMDEstoqueTests */,\n\t\t\t\t);\n\t\t\t}};\n/* End PBXProject section */"
)

# 10. Add TargetAttributes for test target
content = content.replace(
    f"""\t\t\t\t\t{MAIN_TARGET} = {{
\t\t\t\t\t\tDevelopmentTeam = "";
\t\t\t\t\t}};""",
    f"""\t\t\t\t\t{MAIN_TARGET} = {{
\t\t\t\t\t\tDevelopmentTeam = "";
\t\t\t\t\t}};
\t\t\t\t\t{uuids['test_target']} = {{
\t\t\t\t\t\tDevelopmentTeam = "";
\t\t\t\t\t\tTestTargetID = {MAIN_TARGET};
\t\t\t\t\t}};"""
)

# 11. Add PBXSourcesBuildPhase for tests
source_files_str = ",\n".join(
    f'\t\t\t\t{uuids[f"buildfile_{tf}"]} /* {tf} in Sources */' for tf in TEST_FILES
)
test_sources = f"""\t\t{uuids['test_sources_phase']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{source_files_str},
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""

content = content.replace(
    "/* End PBXSourcesBuildPhase section */",
    test_sources + "\n/* End PBXSourcesBuildPhase section */"
)

# 12. Add XCBuildConfiguration for test target
test_debug = f"""\t\t{uuids['debug_config']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_IDENTITY = "iPhone Developer";
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.emdash.mmdestoque.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_VERSION = 5.9;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/MMD Estoque.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MMD Estoque";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};"""

test_release = f"""\t\t{uuids['release_config']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_IDENTITY = "iPhone Developer";
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.emdash.mmdestoque.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "";
\t\t\t\tSWIFT_VERSION = 5.9;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/MMD Estoque.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MMD Estoque";
\t\t\t}};
\t\t\tname = Release;
\t\t}};"""

content = content.replace(
    "/* End XCBuildConfiguration section */",
    test_debug + "\n" + test_release + "\n/* End XCBuildConfiguration section */"
)

# 13. Add XCConfigurationList for test target
test_config_list = f"""\t\t{uuids['config_list']} /* Build configuration list for PBXNativeTarget "MMDEstoqueTests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uuids['debug_config']} /* Debug */,
\t\t\t\t{uuids['release_config']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Debug;
\t\t}};"""

content = content.replace(
    "/* End XCConfigurationList section */",
    test_config_list + "\n/* End XCConfigurationList section */"
)

with open(PBXPROJ, "w") as f:
    f.write(content)

print("Test target added successfully!")
print(f"Test target UUID: {uuids['test_target']}")
print(f"Test files: {len(TEST_FILES)}")
for k, v in uuids.items():
    print(f"  {k}: {v}")
