#!/usr/bin/env python3
"""Regenerate WakeMe.xcodeproj from the source tree. Run after adding source files."""

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def uid(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()[:24].upper()


def collect(folder: Path, suffixes: set[str]) -> list[Path]:
    if not folder.exists():
        return []
    return sorted(
        path for path in folder.rglob("*")
        if path.is_file() and path.suffix in suffixes and path.name != "Info.plist"
    )


def last_type(path: Path) -> str:
    return {".swift": "sourcecode.swift", ".caf": "file"}.get(path.suffix, "text")


app_sources = collect(ROOT / "WakeMe", {".swift"})
shared_sources = collect(ROOT / "Shared", {".swift"})
widget_sources = collect(ROOT / "AlarmLiveActivity", {".swift"})
test_sources = collect(ROOT / "WakeMeTests", {".swift"})
resources = collect(ROOT / "WakeMe", {".caf"})

all_files = app_sources + shared_sources + widget_sources + test_sources + resources

APP = uid("target:app")
WIDGET = uid("target:widget")
TESTS = uid("target:tests")
PROJECT = uid("project")
APP_PRODUCT = uid("product:app")
WIDGET_PRODUCT = uid("product:widget")
TEST_PRODUCT = uid("product:tests")
MAIN_GROUP = uid("group:main")
PRODUCTS_GROUP = uid("group:products")
APP_SOURCES_PHASE = uid("phase:app:sources")
APP_FRAMEWORKS = uid("phase:app:frameworks")
APP_RESOURCES = uid("phase:app:resources")
EMBED = uid("phase:embed")
WIDGET_SOURCES_PHASE = uid("phase:widget:sources")
WIDGET_FRAMEWORKS = uid("phase:widget:frameworks")
WIDGET_RESOURCES = uid("phase:widget:resources")
TEST_SOURCES_PHASE = uid("phase:test:sources")
TEST_FRAMEWORKS = uid("phase:test:frameworks")
TEST_RESOURCES = uid("phase:test:resources")
DEP_WIDGET = uid("dep:widget")
DEP_APP = uid("dep:app")
PROXY_WIDGET = uid("proxy:widget")
PROXY_APP = uid("proxy:app")
PROJECT_LIST = uid("configlist:project")
APP_LIST = uid("configlist:app")
WIDGET_LIST = uid("configlist:widget")
TEST_LIST = uid("configlist:tests")
PROJECT_DEBUG = uid("config:project:debug")
PROJECT_RELEASE = uid("config:project:release")
APP_DEBUG = uid("config:app:debug")
APP_RELEASE = uid("config:app:release")
WIDGET_DEBUG = uid("config:widget:debug")
WIDGET_RELEASE = uid("config:widget:release")
TEST_DEBUG = uid("config:test:debug")
TEST_RELEASE = uid("config:test:release")


def ref(path: Path) -> str:
    return uid(f"ref:{path.relative_to(ROOT)}")


def build(path: Path, target: str) -> str:
    return uid(f"build:{target}:{path.relative_to(ROOT)}")


groups: dict[Path, str] = {}


def group_id(folder: Path) -> str:
    folder = folder.relative_to(ROOT)
    key = ROOT / folder
    if key not in groups:
        groups[key] = uid(f"group:{folder}")
    return groups[key]


for path in all_files:
    current = path.parent
    while current != ROOT:
        group_id(current)
        current = current.parent

lines: list[str] = []


def emit(text: str = "") -> None:
    lines.append(text)


emit("// !$*UTF8*$!")
emit("{")
emit("\tarchiveVersion = 1;")
emit("\tclasses = {};")
emit("\tobjectVersion = 56;")
emit("\tobjects = {")
emit("")
emit("/* Begin PBXBuildFile section */")
for path in app_sources + shared_sources:
    emit(f"\t\t{build(path, 'app')} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref(path)} /* {path.name} */; }};")
for path in resources:
    emit(f"\t\t{build(path, 'app-res')} /* {path.name} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref(path)} /* {path.name} */; }};")
for path in widget_sources + shared_sources:
    emit(f"\t\t{build(path, 'widget')} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref(path)} /* {path.name} */; }};")
for path in test_sources:
    emit(f"\t\t{build(path, 'test')} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref(path)} /* {path.name} */; }};")
emit(f"\t\t{uid('embed-build')} /* AlarmLiveActivity.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {WIDGET_PRODUCT} /* AlarmLiveActivity.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
emit("/* End PBXBuildFile section */")
emit("")
emit("/* Begin PBXContainerItemProxy section */")
emit(f"\t\t{PROXY_WIDGET} /* PBXContainerItemProxy */ = {{")
emit("\t\t\tisa = PBXContainerItemProxy;")
emit(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
emit("\t\t\tproxyType = 1;")
emit(f"\t\t\tremoteGlobalIDString = {WIDGET};")
emit("\t\t\tremoteInfo = AlarmLiveActivity;")
emit("\t\t};")
emit(f"\t\t{PROXY_APP} /* PBXContainerItemProxy */ = {{")
emit("\t\t\tisa = PBXContainerItemProxy;")
emit(f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;")
emit("\t\t\tproxyType = 1;")
emit(f"\t\t\tremoteGlobalIDString = {APP};")
emit("\t\t\tremoteInfo = WakeMe;")
emit("\t\t};")
emit("/* End PBXContainerItemProxy section */")
emit("")
emit("/* Begin PBXCopyFilesBuildPhase section */")
emit(f"\t\t{EMBED} /* Embed Foundation Extensions */ = {{")
emit("\t\t\tisa = PBXCopyFilesBuildPhase;")
emit("\t\t\tbuildActionMask = 2147483647;")
emit("\t\t\tdstPath = \"\";")
emit("\t\t\tdstSubfolderSpec = 13;")
emit("\t\t\tfiles = (")
emit(f"\t\t\t\t{uid('embed-build')} /* AlarmLiveActivity.appex in Embed Foundation Extensions */,")
emit("\t\t\t);")
emit("\t\t\tname = \"Embed Foundation Extensions\";")
emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
emit("\t\t};")
emit("/* End PBXCopyFilesBuildPhase section */")
emit("")
emit("/* Begin PBXFileReference section */")
emit(f"\t\t{APP_PRODUCT} /* WakeMe.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = WakeMe.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
emit(f"\t\t{WIDGET_PRODUCT} /* AlarmLiveActivity.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = AlarmLiveActivity.appex; sourceTree = BUILT_PRODUCTS_DIR; }};")
emit(f"\t\t{TEST_PRODUCT} /* WakeMeTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = WakeMeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
for path in all_files:
    emit(f"\t\t{ref(path)} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = {last_type(path)}; path = {path.name}; sourceTree = \"<group>\"; }};")
emit("/* End PBXFileReference section */")
emit("")
emit("/* Begin PBXFrameworksBuildPhase section */")
for phase, name in ((APP_FRAMEWORKS, "app"), (WIDGET_FRAMEWORKS, "widget"), (TEST_FRAMEWORKS, "tests")):
    emit(f"\t\t{phase} /* Frameworks */ = {{")
    emit("\t\t\tisa = PBXFrameworksBuildPhase;")
    emit("\t\t\tbuildActionMask = 2147483647;")
    emit("\t\t\tfiles = (")
    emit("\t\t\t);")
    emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    emit("\t\t};")
emit("/* End PBXFrameworksBuildPhase section */")
emit("")
emit("/* Begin PBXGroup section */")
emit(f"\t\t{MAIN_GROUP} = {{")
emit("\t\t\tisa = PBXGroup;")
emit("\t\t\tchildren = (")
for folder in (ROOT / "WakeMe", ROOT / "Shared", ROOT / "AlarmLiveActivity", ROOT / "WakeMeTests"):
    if folder.exists():
        emit(f"\t\t\t\t{group_id(folder)} /* {folder.name} */,")
emit(f"\t\t\t\t{PRODUCTS_GROUP} /* Products */,")
emit("\t\t\t);")
emit("\t\t\tsourceTree = \"<group>\";")
emit("\t\t};")
emit(f"\t\t{PRODUCTS_GROUP} /* Products */ = {{")
emit("\t\t\tisa = PBXGroup;")
emit("\t\t\tchildren = (")
emit(f"\t\t\t\t{APP_PRODUCT} /* WakeMe.app */,")
emit(f"\t\t\t\t{WIDGET_PRODUCT} /* AlarmLiveActivity.appex */,")
emit(f"\t\t\t\t{TEST_PRODUCT} /* WakeMeTests.xctest */,")
emit("\t\t\t);")
emit("\t\t\tname = Products;")
emit("\t\t\tsourceTree = \"<group>\";")
emit("\t\t};")

folders = sorted(groups, key=lambda path: len(path.relative_to(ROOT).parts))
for folder in folders:
    rel = folder.relative_to(ROOT)
    children = []
    for child in sorted(folder.iterdir(), key=lambda item: (item.is_file(), item.name)):
        if child.is_dir() and (ROOT / child.relative_to(ROOT)) in groups:
            children.append(f"\t\t\t\t{group_id(child)} /* {child.name} */,")
        elif child.is_file() and child.suffix in {".swift", ".caf"} and child.name != "Info.plist":
            children.append(f"\t\t\t\t{ref(child)} /* {child.name} */,")
    emit(f"\t\t{group_id(folder)} /* {folder.name} */ = {{")
    emit("\t\t\tisa = PBXGroup;")
    emit("\t\t\tchildren = (")
    lines.extend(children)
    emit("\t\t\t);")
    if len(rel.parts) == 1:
        emit(f"\t\t\tpath = {folder.name};")
    else:
        emit(f"\t\t\tpath = {folder.name};")
    emit("\t\t\tsourceTree = \"<group>\";")
    emit("\t\t};")
emit("/* End PBXGroup section */")
emit("")
emit("/* Begin PBXNativeTarget section */")
emit(f"\t\t{APP} /* WakeMe */ = {{")
emit("\t\t\tisa = PBXNativeTarget;")
emit(f"\t\t\tbuildConfigurationList = {APP_LIST} /* Build configuration list for PBXNativeTarget \"WakeMe\" */;")
emit("\t\t\tbuildPhases = (")
emit(f"\t\t\t\t{APP_SOURCES_PHASE} /* Sources */,")
emit(f"\t\t\t\t{APP_FRAMEWORKS} /* Frameworks */,")
emit(f"\t\t\t\t{APP_RESOURCES} /* Resources */,")
emit(f"\t\t\t\t{EMBED} /* Embed Foundation Extensions */,")
emit("\t\t\t);")
emit("\t\t\tbuildRules = (")
emit("\t\t\t);")
emit("\t\t\tdependencies = (")
emit(f"\t\t\t\t{DEP_WIDGET} /* PBXTargetDependency */,")
emit("\t\t\t);")
emit("\t\t\tname = WakeMe;")
emit("\t\t\tproductName = WakeMe;")
emit(f"\t\t\tproductReference = {APP_PRODUCT} /* WakeMe.app */;")
emit("\t\t\tproductType = \"com.apple.product-type.application\";")
emit("\t\t};")
emit(f"\t\t{WIDGET} /* AlarmLiveActivity */ = {{")
emit("\t\t\tisa = PBXNativeTarget;")
emit(f"\t\t\tbuildConfigurationList = {WIDGET_LIST} /* Build configuration list for PBXNativeTarget \"AlarmLiveActivity\" */;")
emit("\t\t\tbuildPhases = (")
emit(f"\t\t\t\t{WIDGET_SOURCES_PHASE} /* Sources */,")
emit(f"\t\t\t\t{WIDGET_FRAMEWORKS} /* Frameworks */,")
emit(f"\t\t\t\t{WIDGET_RESOURCES} /* Resources */,")
emit("\t\t\t);")
emit("\t\t\tbuildRules = (")
emit("\t\t\t);")
emit("\t\t\tdependencies = (")
emit("\t\t\t);")
emit("\t\t\tname = AlarmLiveActivity;")
emit("\t\t\tproductName = AlarmLiveActivity;")
emit(f"\t\t\tproductReference = {WIDGET_PRODUCT} /* AlarmLiveActivity.appex */;")
emit("\t\t\tproductType = \"com.apple.product-type.app-extension\";")
emit("\t\t};")
emit(f"\t\t{TESTS} /* WakeMeTests */ = {{")
emit("\t\t\tisa = PBXNativeTarget;")
emit(f"\t\t\tbuildConfigurationList = {TEST_LIST} /* Build configuration list for PBXNativeTarget \"WakeMeTests\" */;")
emit("\t\t\tbuildPhases = (")
emit(f"\t\t\t\t{TEST_SOURCES_PHASE} /* Sources */,")
emit(f"\t\t\t\t{TEST_FRAMEWORKS} /* Frameworks */,")
emit(f"\t\t\t\t{TEST_RESOURCES} /* Resources */,")
emit("\t\t\t);")
emit("\t\t\tbuildRules = (")
emit("\t\t\t);")
emit("\t\t\tdependencies = (")
emit(f"\t\t\t\t{DEP_APP} /* PBXTargetDependency */,")
emit("\t\t\t);")
emit("\t\t\tname = WakeMeTests;")
emit("\t\t\tproductName = WakeMeTests;")
emit(f"\t\t\tproductReference = {TEST_PRODUCT} /* WakeMeTests.xctest */;")
emit("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
emit("\t\t};")
emit("/* End PBXNativeTarget section */")
emit("")
emit("/* Begin PBXProject section */")
emit(f"\t\t{PROJECT} /* Project object */ = {{")
emit("\t\t\tisa = PBXProject;")
emit("\t\t\tattributes = {")
emit("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
emit("\t\t\t\tLastUpgradeCheck = 2700;")
emit("\t\t\t\tTargetAttributes = {")
emit(f"\t\t\t\t\t{APP} = {{ CreatedOnToolsVersion = 27.0; }};")
emit(f"\t\t\t\t\t{WIDGET} = {{ CreatedOnToolsVersion = 27.0; }};")
emit(f"\t\t\t\t\t{TESTS} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {APP}; }};")
emit("\t\t\t\t};")
emit("\t\t\t};")
emit(f"\t\t\tbuildConfigurationList = {PROJECT_LIST} /* Build configuration list for PBXProject \"WakeMe\" */;")
emit("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
emit("\t\t\tdevelopmentRegion = en;")
emit("\t\t\thasScannedForEncodings = 0;")
emit("\t\t\tknownRegions = ( en, Base, );")
emit(f"\t\t\tmainGroup = {MAIN_GROUP};")
emit(f"\t\t\tproductRefGroup = {PRODUCTS_GROUP} /* Products */;")
emit("\t\t\tprojectDirPath = \"\";")
emit("\t\t\tprojectRoot = \"\";")
emit("\t\t\ttargets = (")
emit(f"\t\t\t\t{APP} /* WakeMe */,")
emit(f"\t\t\t\t{WIDGET} /* AlarmLiveActivity */,")
emit(f"\t\t\t\t{TESTS} /* WakeMeTests */,")
emit("\t\t\t);")
emit("\t\t};")
emit("/* End PBXProject section */")
emit("")
emit("/* Begin PBXResourcesBuildPhase section */")
emit(f"\t\t{APP_RESOURCES} /* Resources */ = {{")
emit("\t\t\tisa = PBXResourcesBuildPhase;")
emit("\t\t\tbuildActionMask = 2147483647;")
emit("\t\t\tfiles = (")
for path in resources:
    emit(f"\t\t\t\t{build(path, 'app-res')} /* {path.name} in Resources */,")
emit("\t\t\t);")
emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
emit("\t\t};")
emit(f"\t\t{WIDGET_RESOURCES} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
emit(f"\t\t{TEST_RESOURCES} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
emit("/* End PBXResourcesBuildPhase section */")
emit("")
emit("/* Begin PBXSourcesBuildPhase section */")
emit(f"\t\t{APP_SOURCES_PHASE} /* Sources */ = {{")
emit("\t\t\tisa = PBXSourcesBuildPhase;")
emit("\t\t\tbuildActionMask = 2147483647;")
emit("\t\t\tfiles = (")
for path in app_sources + shared_sources:
    emit(f"\t\t\t\t{build(path, 'app')} /* {path.name} in Sources */,")
emit("\t\t\t);")
emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
emit("\t\t};")
emit(f"\t\t{WIDGET_SOURCES_PHASE} /* Sources */ = {{")
emit("\t\t\tisa = PBXSourcesBuildPhase;")
emit("\t\t\tbuildActionMask = 2147483647;")
emit("\t\t\tfiles = (")
for path in widget_sources + shared_sources:
    emit(f"\t\t\t\t{build(path, 'widget')} /* {path.name} in Sources */,")
emit("\t\t\t);")
emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
emit("\t\t};")
emit(f"\t\t{TEST_SOURCES_PHASE} /* Sources */ = {{")
emit("\t\t\tisa = PBXSourcesBuildPhase;")
emit("\t\t\tbuildActionMask = 2147483647;")
emit("\t\t\tfiles = (")
for path in test_sources:
    emit(f"\t\t\t\t{build(path, 'test')} /* {path.name} in Sources */,")
emit("\t\t\t);")
emit("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
emit("\t\t};")
emit("/* End PBXSourcesBuildPhase section */")
emit("")
emit("/* Begin PBXTargetDependency section */")
emit(f"\t\t{DEP_WIDGET} /* PBXTargetDependency */ = {{isa = PBXTargetDependency; target = {WIDGET} /* AlarmLiveActivity */; targetProxy = {PROXY_WIDGET} /* PBXContainerItemProxy */; }};")
emit(f"\t\t{DEP_APP} /* PBXTargetDependency */ = {{isa = PBXTargetDependency; target = {APP} /* WakeMe */; targetProxy = {PROXY_APP} /* PBXContainerItemProxy */; }};")
emit("/* End PBXTargetDependency section */")
emit("")

common_project = """
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_NS_ASSERTIONS = YES;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""

common_release = """
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;
"""

target_common = """
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;
"""

emit("/* Begin XCBuildConfiguration section */")
emit(f"\t\t{PROJECT_DEBUG} /* Debug */ = {{ isa = XCBuildConfiguration; buildSettings = {{ {common_project} }}; name = Debug; }};")
emit(f"\t\t{PROJECT_RELEASE} /* Release */ = {{ isa = XCBuildConfiguration; buildSettings = {{ {common_release} }}; name = Release; }};")

app_settings = """
\t\t\t\tCODE_SIGN_ENTITLEMENTS = WakeMe/WakeMe.entitlements;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tINFOPLIST_FILE = WakeMe/Info.plist;
\t\t\t\tINFOPLIST_KEY_NSAlarmKitUsageDescription = "WakeMe rings alarms through silent mode and Focus so a wake-up mission can finish.";
\t\t\t\tINFOPLIST_KEY_NSMicrophoneUsageDescription = "WakeMe turns speech into alarms on this iPhone. Audio never leaves the device.";
\t\t\t\tINFOPLIST_KEY_NSMotionUsageDescription = "WakeMe counts shakes to finish a wake-up mission.";
\t\t\t\tINFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "WakeMe transcribes alarms on this iPhone.";
\t\t\t\tINFOPLIST_KEY_NSSupportsLiveActivities = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.wakeme.WakeMe;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_STRICT_CONCURRENCY = minimal;
"""

emit(f"\t\t{APP_DEBUG} /* Debug */ = {{ isa = XCBuildConfiguration; buildSettings = {{ {target_common} {app_settings} ENABLE_TESTABILITY = YES; }}; name = Debug; }};")
emit(f"\t\t{APP_RELEASE} /* Release */ = {{ isa = XCBuildConfiguration; buildSettings = {{ {target_common} {app_settings} }}; name = Release; }};")

widget_settings = """
\t\t\t\tCODE_SIGN_ENTITLEMENTS = AlarmLiveActivity/AlarmLiveActivity.entitlements;
\t\t\t\tINFOPLIST_FILE = AlarmLiveActivity/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.wakeme.WakeMe.AlarmLiveActivity;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_STRICT_CONCURRENCY = minimal;
"""
emit(f"\t\t{WIDGET_DEBUG} /* Debug */ = {{ isa = XCBuildConfiguration; buildSettings = {{ {target_common} {widget_settings} }}; name = Debug; }};")
emit(f"\t\t{WIDGET_RELEASE} /* Release */ = {{ isa = XCBuildConfiguration; buildSettings = {{ {target_common} {widget_settings} }}; name = Release; }};")

test_settings = """
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.wakeme.WakeMeTests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/WakeMe.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/WakeMe";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;
"""
emit(f"\t\t{TEST_DEBUG} /* Debug */ = {{ isa = XCBuildConfiguration; buildSettings = {{ {test_settings} }}; name = Debug; }};")
emit(f"\t\t{TEST_RELEASE} /* Release */ = {{ isa = XCBuildConfiguration; buildSettings = {{ {test_settings} }}; name = Release; }};")
emit("/* End XCBuildConfiguration section */")
emit("")
emit("/* Begin XCConfigurationList section */")
for list_id, debug, release, name in (
    (PROJECT_LIST, PROJECT_DEBUG, PROJECT_RELEASE, "PBXProject \"WakeMe\""),
    (APP_LIST, APP_DEBUG, APP_RELEASE, "PBXNativeTarget \"WakeMe\""),
    (WIDGET_LIST, WIDGET_DEBUG, WIDGET_RELEASE, "PBXNativeTarget \"AlarmLiveActivity\""),
    (TEST_LIST, TEST_DEBUG, TEST_RELEASE, "PBXNativeTarget \"WakeMeTests\""),
):
    emit(f"\t\t{list_id} /* Build configuration list for {name} */ = {{")
    emit("\t\t\tisa = XCConfigurationList;")
    emit("\t\t\tbuildConfigurations = (")
    emit(f"\t\t\t\t{debug} /* Debug */,")
    emit(f"\t\t\t\t{release} /* Release */,")
    emit("\t\t\t);")
    emit("\t\t\tdefaultConfigurationIsVisible = 0;")
    emit("\t\t\tdefaultConfigurationName = Release;")
    emit("\t\t};")
emit("/* End XCConfigurationList section */")
emit("\t};")
emit(f"\trootObject = {PROJECT} /* Project object */;")
emit("}")

project_dir = ROOT / "WakeMe.xcodeproj"
project_dir.mkdir(exist_ok=True)
(project_dir / "project.pbxproj").write_text("\n".join(lines) + "\n")

scheme_dir = project_dir / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2700"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{APP}"
               BuildableName = "WakeMe.app"
               BlueprintName = "WakeMe"
               ReferencedContainer = "container:WakeMe.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{TESTS}"
               BuildableName = "WakeMeTests.xctest"
               BlueprintName = "WakeMeTests"
               ReferencedContainer = "container:WakeMe.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{TESTS}"
               BuildableName = "WakeMeTests.xctest"
               BlueprintName = "WakeMeTests"
               ReferencedContainer = "container:WakeMe.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{APP}"
            BuildableName = "WakeMe.app"
            BlueprintName = "WakeMe"
            ReferencedContainer = "container:WakeMe.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{APP}"
            BuildableName = "WakeMe.app"
            BlueprintName = "WakeMe"
            ReferencedContainer = "container:WakeMe.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
(scheme_dir / "WakeMe.xcscheme").write_text(scheme)
print(f"Wrote {project_dir / 'project.pbxproj'}")
print(f"app {len(app_sources)} shared {len(shared_sources)} widget {len(widget_sources)} tests {len(test_sources)} sounds {len(resources)}")
