#!/usr/bin/env python3
"""
Generates Vitala.xcodeproj/project.pbxproj.

Walks Vitala/ for .swift files and resources, builds a complete pbxproj
that Xcode can open directly. Includes Firebase SPM dependencies.

Usage:
    python3 scripts/generate_pbxproj.py
"""

import hashlib
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = "Vitala"
APP_DIR = ROOT / APP_NAME
PROJ_DIR = ROOT / f"{APP_NAME}.xcodeproj"
BUNDLE_ID = "com.vitala.healthyliving"
DEPLOYMENT = "17.0"

# Firebase package — disabled in demo mode. Re-enable by populating the list.
FIREBASE_REPO = "https://github.com/firebase/firebase-ios-sdk"
FIREBASE_MIN = "10.29.0"
FIREBASE_PRODUCTS = []   # demo mode: no Firebase dependency

def uid(*parts) -> str:
    """Deterministic 24-char hex UUID from any inputs."""
    h = hashlib.md5("/".join(parts).encode()).hexdigest()
    return h[:24].upper()

def discover_files():
    sources, resources = [], []
    plist_path = None
    entitlements_path = None
    asset_path = None
    google_plist = None
    for path in sorted(APP_DIR.rglob("*")):
        if path.is_dir():
            continue
        rel = path.relative_to(ROOT).as_posix()
        if path.suffix == ".swift":
            sources.append(rel)
        elif path.name == "Info.plist":
            plist_path = rel
        elif path.suffix == ".entitlements":
            entitlements_path = rel
        elif path.suffix == ".xcassets":
            asset_path = rel
        elif path.name == "GoogleService-Info.plist":
            google_plist = rel

    # xcassets is a folder; rglob yields its files. Detect by parents.
    asset_root = None
    for path in APP_DIR.rglob("*"):
        if path.is_dir() and path.suffix == ".xcassets":
            asset_root = path.relative_to(ROOT).as_posix()
            break
    if asset_root:
        # remove inner files added accidentally
        sources = [s for s in sources if not s.startswith(asset_root)]
        resources = []  # not used at granular level
    return sources, plist_path, entitlements_path, asset_root, google_plist


def group_for(path: str) -> list:
    """Split a/b/c/d.swift -> ['a','b','c'] (group chain)."""
    parts = path.split("/")
    return parts[:-1]


def build_pbxproj():
    sources, plist, entitlements, asset_root, google_plist = discover_files()

    # ID generators
    proj_id = uid("project")
    main_group_id = uid("group", "/")
    products_group_id = uid("group", "Products")
    target_id = uid("target", APP_NAME)
    product_ref_id = uid("product", APP_NAME)
    config_list_proj_id = uid("configlist", "project")
    config_list_target_id = uid("configlist", "target")
    debug_proj_id = uid("config", "project", "Debug")
    release_proj_id = uid("config", "project", "Release")
    debug_target_id = uid("config", "target", "Debug")
    release_target_id = uid("config", "target", "Release")
    sources_phase_id = uid("phase", "Sources")
    resources_phase_id = uid("phase", "Resources")
    frameworks_phase_id = uid("phase", "Frameworks")

    # Firebase package + product IDs
    firebase_pkg_id = uid("pkg", "Firebase")
    firebase_product_ids = {p: uid("pkgproduct", p) for p in FIREBASE_PRODUCTS}
    firebase_buildfile_ids = {p: uid("buildfile", "framework", p) for p in FIREBASE_PRODUCTS}

    # File refs
    file_refs = {}            # rel_path -> id
    build_files_for_sources = {}  # rel_path -> id
    for s in sources:
        file_refs[s] = uid("file", s)
        build_files_for_sources[s] = uid("buildfile", "src", s)

    # Resources
    resource_paths = []
    if asset_root:
        resource_paths.append(asset_root)
    if google_plist:
        resource_paths.append(google_plist)
    build_files_for_resources = {}
    for r in resource_paths:
        if r not in file_refs:
            file_refs[r] = uid("file", r)
        build_files_for_resources[r] = uid("buildfile", "res", r)

    # Plist + entitlements as file refs but NOT in build phases
    if plist and plist not in file_refs:
        file_refs[plist] = uid("file", plist)
    if entitlements and entitlements not in file_refs:
        file_refs[entitlements] = uid("file", entitlements)

    # Group tree: build hierarchical groups under Vitala/
    group_ids = {}  # tuple(path_segments) -> id
    group_ids[()] = main_group_id
    group_ids[(APP_NAME,)] = uid("group", APP_NAME)

    def ensure_group(parts):
        if tuple(parts) in group_ids:
            return group_ids[tuple(parts)]
        group_ids[tuple(parts)] = uid("group", "/".join(parts))
        # Ensure parent
        if len(parts) > 1:
            ensure_group(parts[:-1])
        return group_ids[tuple(parts)]

    # All files (sources + resources + plist + entitlements) are mapped to groups
    files_in_group = {}  # tuple -> list of rel_path
    for f in list(file_refs.keys()):
        # Don't put xcassets *contents* in groups; xcassets folder itself is the leaf.
        parts = f.split("/")
        if any(p.endswith(".xcassets") for p in parts[:-1]):
            continue  # skip contents inside xcassets
        # Skip the colorset/Contents.json — they're inside xcassets folder
        group_path = parts[:-1]
        ensure_group(group_path)
        files_in_group.setdefault(tuple(group_path), []).append(f)

    # Subgroups for each group (children groups)
    subgroups = {}  # parent tuple -> list of child names
    for path_tuple in group_ids:
        if not path_tuple:
            continue
        parent = path_tuple[:-1]
        subgroups.setdefault(parent, []).append(path_tuple[-1])

    lines = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {")
    lines.append("\t};")
    lines.append("\tobjectVersion = 60;")
    lines.append("\tobjects = {")
    lines.append("")

    # PBXBuildFile
    lines.append("/* Begin PBXBuildFile section */")
    for s, bid in build_files_for_sources.items():
        fid = file_refs[s]
        name = os.path.basename(s)
        lines.append(f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
    for r, bid in build_files_for_resources.items():
        fid = file_refs[r]
        name = os.path.basename(r)
        lines.append(f"\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
    for p, bid in firebase_buildfile_ids.items():
        lines.append(f"\t\t{bid} /* {p} in Frameworks */ = {{isa = PBXBuildFile; productRef = {firebase_product_ids[p]} /* {p} */; }};")
    lines.append("/* End PBXBuildFile section */")
    lines.append("")

    # PBXFileReference
    lines.append("/* Begin PBXFileReference section */")
    for f, fid in file_refs.items():
        name = os.path.basename(f)
        if f.endswith(".swift"):
            ftype = "sourcecode.swift"
        elif f.endswith(".plist"):
            ftype = "text.plist.xml"
        elif f.endswith(".entitlements"):
            ftype = "text.plist.entitlements"
        elif f.endswith(".xcassets"):
            ftype = "folder.assetcatalog"
        else:
            ftype = "text"
        rel_path = name  # we'll use 'path' relative within group
        lines.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{rel_path}"; sourceTree = "<group>"; }};')

    # Product reference
    lines.append(f'\t\t{product_ref_id} /* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    lines.append("/* End PBXFileReference section */")
    lines.append("")

    # PBXFrameworksBuildPhase
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    lines.append(f"\t\t{frameworks_phase_id} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for p, bid in firebase_buildfile_ids.items():
        lines.append(f"\t\t\t\t{bid} /* {p} in Frameworks */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXFrameworksBuildPhase section */")
    lines.append("")

    # PBXGroup
    lines.append("/* Begin PBXGroup section */")
    # Root group
    root_children = []
    # Vitala/ group
    root_children.append((group_ids[(APP_NAME,)], APP_NAME))
    root_children.append((products_group_id, "Products"))
    lines.append(f"\t\t{main_group_id} = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for cid, cname in root_children:
        lines.append(f"\t\t\t\t{cid} /* {cname} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    # Products group
    lines.append(f"\t\t{products_group_id} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{product_ref_id} /* {APP_NAME}.app */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    # All other groups
    for parts, gid in group_ids.items():
        if parts == ():
            continue
        children_files = files_in_group.get(parts, [])
        children_groups = subgroups.get(parts, [])
        gname = parts[-1]
        # Compute relative path: groups under Vitala/ have path = name; root Vitala group has path = Vitala
        path_str = gname
        lines.append(f"\t\t{gid} /* {gname} */ = {{")
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        # subgroups first (alphabetical)
        for child_name in sorted(children_groups):
            child_id = group_ids[parts + (child_name,)]
            lines.append(f"\t\t\t\t{child_id} /* {child_name} */,")
        # then files (alphabetical by filename)
        for f in sorted(children_files, key=lambda p: os.path.basename(p).lower()):
            fid = file_refs[f]
            name = os.path.basename(f)
            lines.append(f"\t\t\t\t{fid} /* {name} */,")
        lines.append("\t\t\t);")
        lines.append(f'\t\t\tpath = "{path_str}";')
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")
    lines.append("/* End PBXGroup section */")
    lines.append("")

    # PBXNativeTarget
    lines.append("/* Begin PBXNativeTarget section */")
    lines.append(f"\t\t{target_id} /* {APP_NAME} */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {config_list_target_id} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{sources_phase_id} /* Sources */,")
    lines.append(f"\t\t\t\t{frameworks_phase_id} /* Frameworks */,")
    lines.append(f"\t\t\t\t{resources_phase_id} /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = ();")
    lines.append("\t\t\tdependencies = ();")
    lines.append(f"\t\t\tname = {APP_NAME};")
    if firebase_product_ids:
        lines.append("\t\t\tpackageProductDependencies = (")
        for p, pid in firebase_product_ids.items():
            lines.append(f"\t\t\t\t{pid} /* {p} */,")
        lines.append("\t\t\t);")
    lines.append(f"\t\t\tproductName = {APP_NAME};")
    lines.append(f"\t\t\tproductReference = {product_ref_id} /* {APP_NAME}.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")
    lines.append("")

    # PBXProject
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{proj_id} /* Project object */ = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    lines.append("\t\t\t\tLastUpgradeCheck = 1500;")
    lines.append("\t\t\t\tTargetAttributes = {")
    lines.append(f"\t\t\t\t\t{target_id} = {{")
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t};")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tbuildConfigurationList = {config_list_proj_id} /* Build configuration list for PBXProject \"{APP_NAME}\" */;")
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\t\tdevelopmentRegion = en;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (")
    lines.append("\t\t\t\ten,")
    lines.append("\t\t\t\tBase,")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tmainGroup = {main_group_id};")
    if firebase_product_ids:
        lines.append("\t\t\tpackageReferences = (")
        lines.append(f"\t\t\t\t{firebase_pkg_id} /* XCRemoteSwiftPackageReference \"firebase-ios-sdk\" */,")
        lines.append("\t\t\t);")
    lines.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    lines.append("\t\t\tprojectDirPath = \"\";")
    lines.append("\t\t\tprojectRoot = \"\";")
    lines.append("\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{target_id} /* {APP_NAME} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */")
    lines.append("")

    # PBXResourcesBuildPhase
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{resources_phase_id} /* Resources */ = {{")
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for r, bid in build_files_for_resources.items():
        name = os.path.basename(r)
        lines.append(f"\t\t\t\t{bid} /* {name} in Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    lines.append("")

    # PBXSourcesBuildPhase
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    lines.append(f"\t\t{sources_phase_id} /* Sources */ = {{")
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for s, bid in build_files_for_sources.items():
        name = os.path.basename(s)
        lines.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXSourcesBuildPhase section */")
    lines.append("")

    # XCBuildConfiguration (project + target)
    lines.append("/* Begin XCBuildConfiguration section */")

    def proj_config_block(cid, name):
        out = []
        out.append(f"\t\t{cid} /* {name} */ = {{")
        out.append("\t\t\tisa = XCBuildConfiguration;")
        out.append("\t\t\tbuildSettings = {")
        out.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        out.append("\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;")
        out.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
        out.append("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
        out.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
        out.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        out.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
        out.append("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
        out.append("\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;")
        out.append("\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;")
        out.append("\t\t\t\tCLANG_WARN_COMMA = YES;")
        out.append("\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;")
        out.append("\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;")
        out.append("\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;")
        out.append("\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;")
        out.append("\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;")
        out.append("\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;")
        out.append("\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;")
        out.append("\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;")
        out.append("\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;")
        out.append("\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;")
        out.append("\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;")
        out.append("\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;")
        out.append("\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;")
        out.append("\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;")
        out.append("\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;")
        out.append("\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;")
        out.append("\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;")
        out.append("\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;")
        out.append("\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;")
        out.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
        out.append(f'\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = "{DEPLOYMENT}";')
        out.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
        out.append("\t\t\t\tENABLE_NS_ASSERTIONS = " + ("YES" if name == "Debug" else "NO") + ";")
        out.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
        out.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;")
        out.append("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
        out.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
        out.append("\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
        out.append("\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
        out.append("\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
        out.append("\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
        out.append("\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
        out.append("\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
        out.append("\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;")
        out.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = " + ("INCLUDE_SOURCE" if name == "Debug" else "NO") + ";")
        out.append("\t\t\t\tMTL_FAST_MATH = YES;")
        out.append("\t\t\t\tONLY_ACTIVE_ARCH = " + ("YES" if name == "Debug" else "NO") + ";")
        out.append("\t\t\t\tSDKROOT = iphoneos;")
        if name == "Debug":
            out.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
            out.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
        else:
            out.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
            out.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
            out.append("\t\t\t\tVALIDATE_PRODUCT = YES;")
        out.append("\t\t\t};")
        out.append(f"\t\t\tname = {name};")
        out.append("\t\t};")
        return out

    def target_config_block(cid, name):
        out = []
        out.append(f"\t\t{cid} /* {name} */ = {{")
        out.append("\t\t\tisa = XCBuildConfiguration;")
        out.append("\t\t\tbuildSettings = {")
        out.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        out.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
        out.append(f"\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"{entitlements}\";")
        out.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        out.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        out.append("\t\t\t\tDEVELOPMENT_ASSET_PATHS = \"\";")
        out.append("\t\t\t\tENABLE_PREVIEWS = YES;")
        out.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
        out.append(f'\t\t\t\tINFOPLIST_FILE = "{plist}";')
        out.append('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
        out.append('\t\t\t\t\t"$(inherited)",')
        out.append('\t\t\t\t\t"@executable_path/Frameworks",')
        out.append('\t\t\t\t);')
        out.append("\t\t\t\tMARKETING_VERSION = 1.0;")
        out.append(f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE_ID}";')
        out.append(f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        out.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        out.append("\t\t\t\tSWIFT_VERSION = 5.0;")
        out.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        out.append("\t\t\t};")
        out.append(f"\t\t\tname = {name};")
        out.append("\t\t};")
        return out

    lines += proj_config_block(debug_proj_id, "Debug")
    lines += proj_config_block(release_proj_id, "Release")
    lines += target_config_block(debug_target_id, "Debug")
    lines += target_config_block(release_target_id, "Release")
    lines.append("/* End XCBuildConfiguration section */")
    lines.append("")

    # XCConfigurationList
    lines.append("/* Begin XCConfigurationList section */")
    lines.append(f"\t\t{config_list_proj_id} /* Build configuration list for PBXProject \"{APP_NAME}\" */ = {{")
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{debug_proj_id} /* Debug */,")
    lines.append(f"\t\t\t\t{release_proj_id} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    lines.append(f"\t\t{config_list_target_id} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */ = {{")
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{debug_target_id} /* Debug */,")
    lines.append(f"\t\t\t\t{release_target_id} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    lines.append("/* End XCConfigurationList section */")
    lines.append("")

    # XCRemoteSwiftPackageReference (skip if no SPM packages)
    if firebase_product_ids:
        lines.append("/* Begin XCRemoteSwiftPackageReference section */")
        lines.append(f"\t\t{firebase_pkg_id} /* XCRemoteSwiftPackageReference \"firebase-ios-sdk\" */ = {{")
        lines.append("\t\t\tisa = XCRemoteSwiftPackageReference;")
        lines.append(f"\t\t\trepositoryURL = \"{FIREBASE_REPO}\";")
        lines.append("\t\t\trequirement = {")
        lines.append("\t\t\t\tkind = upToNextMajorVersion;")
        lines.append(f"\t\t\t\tminimumVersion = {FIREBASE_MIN};")
        lines.append("\t\t\t};")
        lines.append("\t\t};")
        lines.append("/* End XCRemoteSwiftPackageReference section */")
        lines.append("")

        # XCSwiftPackageProductDependency
        lines.append("/* Begin XCSwiftPackageProductDependency section */")
        for p, pid in firebase_product_ids.items():
            lines.append(f"\t\t{pid} /* {p} */ = {{")
            lines.append("\t\t\tisa = XCSwiftPackageProductDependency;")
            lines.append(f"\t\t\tpackage = {firebase_pkg_id} /* XCRemoteSwiftPackageReference \"firebase-ios-sdk\" */;")
            lines.append(f"\t\t\tproductName = {p};")
            lines.append("\t\t};")
        lines.append("/* End XCSwiftPackageProductDependency section */")
        lines.append("")

    lines.append("\t};")
    lines.append(f"\trootObject = {proj_id} /* Project object */;")
    lines.append("}")
    return "\n".join(lines)


def write_workspace_files(proj_dir: Path):
    # contents.xcworkspacedata
    ws_dir = proj_dir / "project.xcworkspace"
    ws_dir.mkdir(parents=True, exist_ok=True)
    (ws_dir / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Workspace version = "1.0">\n'
        '   <FileRef location = "self:"></FileRef>\n'
        '</Workspace>\n'
    )
    # IDEWorkspaceChecks.plist
    shared = ws_dir / "xcshareddata"
    shared.mkdir(parents=True, exist_ok=True)
    (shared / "IDEWorkspaceChecks.plist").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n'
        '<dict>\n'
        '\t<key>IDEDidComputeMac32BitWarning</key>\n'
        '\t<true/>\n'
        '</dict>\n'
        '</plist>\n'
    )
    # Schemes
    schemes = proj_dir / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    scheme_path = schemes / f"{APP_NAME}.xcscheme"
    target_id = uid("target", APP_NAME)
    product_ref_id = uid("product", APP_NAME)
    proj_id = uid("project")
    scheme_path.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="{APP_NAME}.app" BlueprintName="{APP_NAME}" ReferencedContainer="container:{APP_NAME}.xcodeproj"></BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"></TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="{APP_NAME}.app" BlueprintName="{APP_NAME}" ReferencedContainer="container:{APP_NAME}.xcodeproj"></BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="{APP_NAME}.app" BlueprintName="{APP_NAME}" ReferencedContainer="container:{APP_NAME}.xcodeproj"></BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"></ArchiveAction>
</Scheme>
''')


def main():
    PROJ_DIR.mkdir(exist_ok=True)
    text = build_pbxproj()
    (PROJ_DIR / "project.pbxproj").write_text(text)
    write_workspace_files(PROJ_DIR)
    print(f"Wrote {PROJ_DIR / 'project.pbxproj'}")

if __name__ == "__main__":
    main()
