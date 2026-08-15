#!/usr/bin/env python3
"""Embed WGExtension + WireGuardKit SPM into macOS/iOS Runner.xcodeproj."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEAM = "846K6R4WU8"  # existing Personal Team from Xcode prefs / prior local signing


def ids(prefix: str) -> dict[str, str]:
    # 24-char hex only — Xcode drops non-hex object IDs.
    keys = [
        "build_swift",
        "build_embed",
        "build_wgkit",
        "file_swift",
        "file_plist",
        "file_ent",
        "file_appex",
        "proxy",
        "embed_phase",
        "fw_phase",
        "group",
        "target",
        "cfglist",
        "src_phase",
        "res_phase",
        "dep",
        "pkg_ref",
        "pkg_prod",
        "cfg_debug",
        "cfg_release",
        "cfg_profile",
    ]
    base = int(prefix, 16)
    return {k: f"{base + i:024X}" for i, k in enumerate(keys)}


def ext_build_settings(platform: str) -> str:
    if platform == "macos":
        return f"""
				CODE_SIGN_ENTITLEMENTS = WGExtension/WGExtension.entitlements;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = {TEAM};
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = WGExtension/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = WGExtension;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@executable_path/../../../../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 12.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.netbridge.netbridge.WGExtension;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
"""
    return f"""
				CODE_SIGN_ENTITLEMENTS = WGExtension/WGExtension.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = {TEAM};
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = WGExtension/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = WGExtension;
				IPHONEOS_DEPLOYMENT_TARGET = 15.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.netbridge.netbridge.WGExtension;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
"""


def patch_macos() -> None:
    path = ROOT / "macos/Runner.xcodeproj/project.pbxproj"
    t = path.read_text()
    I = ids("F10A01")
    if I["target"] in t:
        print("macOS already patched")
        return

    portal = "33CC10E52044A3C60003C045"
    root = "33CC10E52044A3C60003C045"

    t = t.replace(
        "/* End PBXBuildFile section */",
        f"\t\t{I['build_swift']} /* PacketTunnelProvider.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {I['file_swift']} /* PacketTunnelProvider.swift */; }};\n"
        f"\t\t{I['build_embed']} /* WGExtension.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {I['file_appex']} /* WGExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
        f"\t\t{I['build_wgkit']} /* WireGuardKit in Frameworks */ = {{isa = PBXBuildFile; productRef = {I['pkg_prod']} /* WireGuardKit */; }};\n"
        "/* End PBXBuildFile section */",
    )
    t = t.replace(
        "/* End PBXContainerItemProxy section */",
        f"\t\t{I['proxy']} /* PBXContainerItemProxy */ = {{\n"
        f"\t\t\tisa = PBXContainerItemProxy;\n"
        f"\t\t\tcontainerPortal = {portal} /* Project object */;\n"
        f"\t\t\tproxyType = 1;\n"
        f"\t\t\tremoteGlobalIDString = {I['target']};\n"
        f"\t\t\tremoteInfo = WGExtension;\n"
        f"\t\t}};\n"
        "/* End PBXContainerItemProxy section */",
    )
    t = t.replace(
        "/* End PBXCopyFilesBuildPhase section */",
        f"\t\t{I['embed_phase']} /* Embed Foundation Extensions */ = {{\n"
        f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tdstPath = \"\";\n"
        f"\t\t\tdstSubfolderSpec = 13;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{I['build_embed']} /* WGExtension.appex in Embed Foundation Extensions */,\n"
        f"\t\t\t);\n"
        f"\t\t\tname = \"Embed Foundation Extensions\";\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
        "/* End PBXCopyFilesBuildPhase section */",
    )
    t = t.replace(
        "/* End PBXFileReference section */",
        f"\t\t{I['file_swift']} /* PacketTunnelProvider.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PacketTunnelProvider.swift; sourceTree = \"<group>\"; }};\n"
        f"\t\t{I['file_plist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
        f"\t\t{I['file_ent']} /* WGExtension.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = WGExtension.entitlements; sourceTree = \"<group>\"; }};\n"
        f"\t\t{I['file_appex']} /* WGExtension.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = WGExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
        "/* End PBXFileReference section */",
    )
    t = t.replace(
        "/* End PBXFrameworksBuildPhase section */",
        f"\t\t{I['fw_phase']} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{I['build_wgkit']} /* WireGuardKit in Frameworks */,\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
        "/* End PBXFrameworksBuildPhase section */",
    )
    t = t.replace(
        "/* End PBXGroup section */",
        f"\t\t{I['group']} /* WGExtension */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"\t\t\t\t{I['file_swift']} /* PacketTunnelProvider.swift */,\n"
        f"\t\t\t\t{I['file_plist']} /* Info.plist */,\n"
        f"\t\t\t\t{I['file_ent']} /* WGExtension.entitlements */,\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = WGExtension;\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
        "/* End PBXGroup section */",
    )
    t = t.replace(
        "\t\t\tchildren = (\n"
        "\t\t\t\t33FAB671232836740065AC1E /* Runner */,\n"
        "\t\t\t\t33CEB47122A05771004F2AC0 /* Flutter */,\n"
        "\t\t\t\t331C80D6294CF71000263BE5 /* RunnerTests */,\n"
        "\t\t\t\t33CC10EE2044A3C60003C045 /* Products */,\n"
        "\t\t\t\tD73912EC22F37F3D000D13A0 /* Frameworks */,\n"
        "\t\t\t\t3C460254390E56561709771A /* Pods */,\n"
        "\t\t\t);",
        "\t\t\tchildren = (\n"
        "\t\t\t\t33FAB671232836740065AC1E /* Runner */,\n"
        f"\t\t\t\t{I['group']} /* WGExtension */,\n"
        "\t\t\t\t33CEB47122A05771004F2AC0 /* Flutter */,\n"
        "\t\t\t\t331C80D6294CF71000263BE5 /* RunnerTests */,\n"
        "\t\t\t\t33CC10EE2044A3C60003C045 /* Products */,\n"
        "\t\t\t\tD73912EC22F37F3D000D13A0 /* Frameworks */,\n"
        "\t\t\t\t3C460254390E56561709771A /* Pods */,\n"
        "\t\t\t);",
    )
    t = t.replace(
        "\t\t\tchildren = (\n"
        "\t\t\t\t33CC10ED2044A3C60003C045 /* netbridge.app */,\n"
        "\t\t\t\t331C80D5294CF71000263BE5 /* RunnerTests.xctest */,\n"
        "\t\t\t);",
        "\t\t\tchildren = (\n"
        "\t\t\t\t33CC10ED2044A3C60003C045 /* netbridge.app */,\n"
        f"\t\t\t\t{I['file_appex']} /* WGExtension.appex */,\n"
        "\t\t\t\t331C80D5294CF71000263BE5 /* RunnerTests.xctest */,\n"
        "\t\t\t);",
    )
    t = t.replace(
        "/* End PBXNativeTarget section */",
        f"\t\t{I['target']} /* WGExtension */ = {{\n"
        f"\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {I['cfglist']} /* Build configuration list for PBXNativeTarget \"WGExtension\" */;\n"
        f"\t\t\tbuildPhases = (\n"
        f"\t\t\t\t{I['src_phase']} /* Sources */,\n"
        f"\t\t\t\t{I['fw_phase']} /* Frameworks */,\n"
        f"\t\t\t\t{I['res_phase']} /* Resources */,\n"
        f"\t\t\t);\n"
        f"\t\t\tbuildRules = (\n"
        f"\t\t\t);\n"
        f"\t\t\tdependencies = (\n"
        f"\t\t\t);\n"
        f"\t\t\tname = WGExtension;\n"
        f"\t\t\tpackageProductDependencies = (\n"
        f"\t\t\t\t{I['pkg_prod']} /* WireGuardKit */,\n"
        f"\t\t\t);\n"
        f"\t\t\tproductName = WGExtension;\n"
        f"\t\t\tproductReference = {I['file_appex']} /* WGExtension.appex */;\n"
        f"\t\t\tproductType = \"com.apple.product-type.app-extension\";\n"
        f"\t\t}};\n"
        "/* End PBXNativeTarget section */",
    )
    t = t.replace(
        "\t\t\tbuildPhases = (\n"
        "\t\t\t\t0841346DD15EB5AFFF704ACF /* [CP] Check Pods Manifest.lock */,\n"
        "\t\t\t\t33CC10E92044A3C60003C045 /* Sources */,\n"
        "\t\t\t\t33CC10EA2044A3C60003C045 /* Frameworks */,\n"
        "\t\t\t\t33CC10EB2044A3C60003C045 /* Resources */,\n"
        "\t\t\t\t33CC110E2044A8840003C045 /* Bundle Framework */,\n"
        "\t\t\t\t3399D490228B24CF009A79C7 /* ShellScript */,\n"
        "\t\t\t\t53E34CF402F092F5AE50836C /* [CP] Embed Pods Frameworks */,\n"
        "\t\t\t);\n"
        "\t\t\tbuildRules = (\n"
        "\t\t\t);\n"
        "\t\t\tdependencies = (\n"
        "\t\t\t\t33CC11202044C79F0003C045 /* PBXTargetDependency */,\n"
        "\t\t\t);\n"
        "\t\t\tname = Runner;",
        "\t\t\tbuildPhases = (\n"
        "\t\t\t\t0841346DD15EB5AFFF704ACF /* [CP] Check Pods Manifest.lock */,\n"
        "\t\t\t\t33CC10E92044A3C60003C045 /* Sources */,\n"
        "\t\t\t\t33CC10EA2044A3C60003C045 /* Frameworks */,\n"
        "\t\t\t\t33CC10EB2044A3C60003C045 /* Resources */,\n"
        f"\t\t\t\t{I['embed_phase']} /* Embed Foundation Extensions */,\n"
        "\t\t\t\t33CC110E2044A8840003C045 /* Bundle Framework */,\n"
        "\t\t\t\t3399D490228B24CF009A79C7 /* ShellScript */,\n"
        "\t\t\t\t53E34CF402F092F5AE50836C /* [CP] Embed Pods Frameworks */,\n"
        "\t\t\t);\n"
        "\t\t\tbuildRules = (\n"
        "\t\t\t);\n"
        "\t\t\tdependencies = (\n"
        "\t\t\t\t33CC11202044C79F0003C045 /* PBXTargetDependency */,\n"
        f"\t\t\t\t{I['dep']} /* PBXTargetDependency */,\n"
        "\t\t\t);\n"
        "\t\t\tname = Runner;",
    )
    t = t.replace(
        "\t\t\t\t\t33CC10EC2044A3C60003C045 = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 9.2;\n"
        "\t\t\t\t\t\tLastSwiftMigration = 1100;\n"
        "\t\t\t\t\t\tSystemCapabilities = {\n"
        "\t\t\t\t\t\t\tcom.apple.Sandbox = {\n"
        "\t\t\t\t\t\t\t\tenabled = 1;\n"
        "\t\t\t\t\t\t\t};\n"
        "\t\t\t\t\t\t};\n"
        "\t\t\t\t\t};",
        "\t\t\t\t\t33CC10EC2044A3C60003C045 = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 9.2;\n"
        "\t\t\t\t\t\tLastSwiftMigration = 1100;\n"
        "\t\t\t\t\t\tProvisioningStyle = Automatic;\n"
        "\t\t\t\t\t\tSystemCapabilities = {\n"
        "\t\t\t\t\t\t\tcom.apple.Sandbox = {\n"
        "\t\t\t\t\t\t\t\tenabled = 1;\n"
        "\t\t\t\t\t\t\t};\n"
        "\t\t\t\t\t\t};\n"
        "\t\t\t\t\t};\n"
        f"\t\t\t\t\t{I['target']} = {{\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n"
        "\t\t\t\t\t\tProvisioningStyle = Automatic;\n"
        "\t\t\t\t\t};",
    )
    t = t.replace(
        "\t\t\tmainGroup = 33CC10E42044A3C60003C045;\n"
        "\t\t\tproductRefGroup = 33CC10EE2044A3C60003C045 /* Products */;",
        "\t\t\tmainGroup = 33CC10E42044A3C60003C045;\n"
        "\t\t\tpackageReferences = (\n"
        f"\t\t\t\t{I['pkg_ref']} /* XCRemoteSwiftPackageReference \"wireguard-apple\" */,\n"
        "\t\t\t);\n"
        "\t\t\tproductRefGroup = 33CC10EE2044A3C60003C045 /* Products */;",
    )
    t = t.replace(
        "\t\t\ttargets = (\n"
        "\t\t\t\t33CC10EC2044A3C60003C045 /* Runner */,\n"
        "\t\t\t\t331C80D4294CF70F00263BE5 /* RunnerTests */,\n"
        "\t\t\t\t33CC111A2044C6BA0003C045 /* Flutter Assemble */,\n"
        "\t\t\t);",
        "\t\t\ttargets = (\n"
        "\t\t\t\t33CC10EC2044A3C60003C045 /* Runner */,\n"
        f"\t\t\t\t{I['target']} /* WGExtension */,\n"
        "\t\t\t\t331C80D4294CF70F00263BE5 /* RunnerTests */,\n"
        "\t\t\t\t33CC111A2044C6BA0003C045 /* Flutter Assemble */,\n"
        "\t\t\t);",
    )
    t = t.replace(
        "/* End PBXResourcesBuildPhase section */",
        f"\t\t{I['res_phase']} /* Resources */ = {{\n"
        "\t\t\tisa = PBXResourcesBuildPhase;\n"
        "\t\t\tbuildActionMask = 2147483647;\n"
        "\t\t\tfiles = (\n"
        "\t\t\t);\n"
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        "\t\t};\n"
        "/* End PBXResourcesBuildPhase section */",
    )
    t = t.replace(
        "/* End PBXSourcesBuildPhase section */",
        f"\t\t{I['src_phase']} /* Sources */ = {{\n"
        "\t\t\tisa = PBXSourcesBuildPhase;\n"
        "\t\t\tbuildActionMask = 2147483647;\n"
        "\t\t\tfiles = (\n"
        f"\t\t\t\t{I['build_swift']} /* PacketTunnelProvider.swift in Sources */,\n"
        "\t\t\t);\n"
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        "\t\t};\n"
        "/* End PBXSourcesBuildPhase section */",
    )
    t = t.replace(
        "/* End PBXTargetDependency section */",
        f"\t\t{I['dep']} /* PBXTargetDependency */ = {{\n"
        "\t\t\tisa = PBXTargetDependency;\n"
        f"\t\t\ttarget = {I['target']} /* WGExtension */;\n"
        f"\t\t\ttargetProxy = {I['proxy']} /* PBXContainerItemProxy */;\n"
        "\t\t};\n"
        "/* End PBXTargetDependency section */",
    )

    # Runner signing: switch AdHoc → NE entitlements + Automatic + Team
    # Committed project uses CODE_SIGN_IDENTITY = "-", Manual, empty TEAM.
    # Order in file: Profile, Debug, Release.
    runner_sign_old = (
        "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/AdHoc.entitlements;\n"
        '\t\t\t\tCODE_SIGN_IDENTITY = "-";\n'
        "\t\t\t\tCODE_SIGN_STYLE = Manual;\n"
        "\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;\n"
        '\t\t\t\tDEVELOPMENT_TEAM = "";'
    )
    if t.count(runner_sign_old) < 3:
        raise SystemExit(
            f"macOS expected 3 AdHoc Runner blocks, found {t.count(runner_sign_old)}"
        )
    runner_sign_ne_dbg = (
        "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;\n"
        '\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";\n'
        "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
        "\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;\n"
        f"\t\t\t\tDEVELOPMENT_TEAM = {TEAM};\n"
        "\t\t\t\tENABLE_HARDENED_RUNTIME = YES;"
    )
    runner_sign_ne_rel = (
        "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;\n"
        '\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";\n'
        "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
        "\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;\n"
        f"\t\t\t\tDEVELOPMENT_TEAM = {TEAM};\n"
        "\t\t\t\tENABLE_HARDENED_RUNTIME = YES;"
    )
    # Profile
    t = t.replace(runner_sign_old, runner_sign_ne_dbg, 1)
    # Debug
    t = t.replace(runner_sign_old, runner_sign_ne_dbg, 1)
    # Release
    t = t.replace(runner_sign_old, runner_sign_ne_rel, 1)

    settings = ext_build_settings("macos")
    cfgs = ""
    for key, name in [
        ("cfg_debug", "Debug"),
        ("cfg_release", "Release"),
        ("cfg_profile", "Profile"),
    ]:
        cfgs += (
            f"\t\t{I[key]} /* {name} */ = {{\n"
            f"\t\t\tisa = XCBuildConfiguration;\n"
            f"\t\t\tbuildSettings = {{{settings}\t\t\t}};\n"
            f"\t\t\tname = {name};\n"
            f"\t\t}};\n"
        )
    t = t.replace(
        "/* End XCBuildConfiguration section */",
        cfgs + "/* End XCBuildConfiguration section */",
    )
    t = t.replace(
        "/* End XCConfigurationList section */",
        f"\t\t{I['cfglist']} /* Build configuration list for PBXNativeTarget \"WGExtension\" */ = {{\n"
        "\t\t\tisa = XCConfigurationList;\n"
        "\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{I['cfg_debug']} /* Debug */,\n"
        f"\t\t\t\t{I['cfg_release']} /* Release */,\n"
        f"\t\t\t\t{I['cfg_profile']} /* Profile */,\n"
        "\t\t\t);\n"
        "\t\t\tdefaultConfigurationIsVisible = 0;\n"
        "\t\t\tdefaultConfigurationName = Release;\n"
        "\t\t};\n"
        "/* End XCConfigurationList section */",
    )
    spm = (
        "/* Begin XCRemoteSwiftPackageReference section */\n"
        f"\t\t{I['pkg_ref']} /* XCRemoteSwiftPackageReference \"wireguard-apple\" */ = {{\n"
        "\t\t\tisa = XCRemoteSwiftPackageReference;\n"
        '\t\t\trepositoryURL = "https://github.com/passepartoutvpn/wireguard-apple";\n'
        "\t\t\trequirement = {\n"
        "\t\t\t\tkind = upToNextMajorVersion;\n"
        "\t\t\t\tminimumVersion = 1.0.17;\n"
        "\t\t\t};\n"
        "\t\t};\n"
        "/* End XCRemoteSwiftPackageReference section */\n\n"
        "/* Begin XCSwiftPackageProductDependency section */\n"
        f"\t\t{I['pkg_prod']} /* WireGuardKit */ = {{\n"
        "\t\t\tisa = XCSwiftPackageProductDependency;\n"
        f"\t\t\tpackage = {I['pkg_ref']} /* XCRemoteSwiftPackageReference \"wireguard-apple\" */;\n"
        "\t\t\tproductName = WireGuardKit;\n"
        "\t\t};\n"
        "/* End XCSwiftPackageProductDependency section */\n"
    )
    t = t.replace(
        f"\t}};\n\trootObject = {root} /* Project object */;",
        f"\t}};\n{spm}\trootObject = {root} /* Project object */;",
    )
    path.write_text(t)
    print("patched macOS", path)


def patch_ios() -> None:
    path = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    t = path.read_text()
    I = ids("F10B01")
    if I["target"] in t:
        print("iOS already patched")
        return

    portal = "97C146E61CF9000F007C117D"
    root = "97C146E61CF9000F007C117D"

    t = t.replace(
        "/* End PBXBuildFile section */",
        f"\t\t{I['build_swift']} /* PacketTunnelProvider.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {I['file_swift']} /* PacketTunnelProvider.swift */; }};\n"
        f"\t\t{I['build_embed']} /* WGExtension.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {I['file_appex']} /* WGExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
        f"\t\t{I['build_wgkit']} /* WireGuardKit in Frameworks */ = {{isa = PBXBuildFile; productRef = {I['pkg_prod']} /* WireGuardKit */; }};\n"
        "/* End PBXBuildFile section */",
    )
    t = t.replace(
        "/* End PBXContainerItemProxy section */",
        f"\t\t{I['proxy']} /* PBXContainerItemProxy */ = {{\n"
        f"\t\t\tisa = PBXContainerItemProxy;\n"
        f"\t\t\tcontainerPortal = {portal} /* Project object */;\n"
        f"\t\t\tproxyType = 1;\n"
        f"\t\t\tremoteGlobalIDString = {I['target']};\n"
        f"\t\t\tremoteInfo = WGExtension;\n"
        f"\t\t}};\n"
        "/* End PBXContainerItemProxy section */",
    )
    t = t.replace(
        "/* End PBXCopyFilesBuildPhase section */",
        f"\t\t{I['embed_phase']} /* Embed Foundation Extensions */ = {{\n"
        f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tdstPath = \"\";\n"
        f"\t\t\tdstSubfolderSpec = 13;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{I['build_embed']} /* WGExtension.appex in Embed Foundation Extensions */,\n"
        f"\t\t\t);\n"
        f"\t\t\tname = \"Embed Foundation Extensions\";\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
        "/* End PBXCopyFilesBuildPhase section */",
    )
    t = t.replace(
        "/* End PBXFileReference section */",
        f"\t\t{I['file_swift']} /* PacketTunnelProvider.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PacketTunnelProvider.swift; sourceTree = \"<group>\"; }};\n"
        f"\t\t{I['file_plist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
        f"\t\t{I['file_ent']} /* WGExtension.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = WGExtension.entitlements; sourceTree = \"<group>\"; }};\n"
        f"\t\t{I['file_appex']} /* WGExtension.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = WGExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
        "/* End PBXFileReference section */",
    )
    t = t.replace(
        "/* End PBXFrameworksBuildPhase section */",
        f"\t\t{I['fw_phase']} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{I['build_wgkit']} /* WireGuardKit in Frameworks */,\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
        "/* End PBXFrameworksBuildPhase section */",
    )
    t = t.replace(
        "/* End PBXGroup section */",
        f"\t\t{I['group']} /* WGExtension */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"\t\t\t\t{I['file_swift']} /* PacketTunnelProvider.swift */,\n"
        f"\t\t\t\t{I['file_plist']} /* Info.plist */,\n"
        f"\t\t\t\t{I['file_ent']} /* WGExtension.entitlements */,\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = WGExtension;\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
        "/* End PBXGroup section */",
    )
    t = t.replace(
        "\t\t\tchildren = (\n"
        "\t\t\t\t9740EEB11CF90186004384FC /* Flutter */,\n"
        "\t\t\t\t97C146F01CF9000F007C117D /* Runner */,\n"
        "\t\t\t\t97C146EF1CF9000F007C117D /* Products */,\n"
        "\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n"
        "\t\t\t\tB3F2CE1A170B058972F850AD /* Pods */,\n"
        "\t\t\t\t0803A1C97BA7CB2B6A5D4047 /* Frameworks */,\n"
        "\t\t\t);",
        "\t\t\tchildren = (\n"
        "\t\t\t\t9740EEB11CF90186004384FC /* Flutter */,\n"
        "\t\t\t\t97C146F01CF9000F007C117D /* Runner */,\n"
        f"\t\t\t\t{I['group']} /* WGExtension */,\n"
        "\t\t\t\t97C146EF1CF9000F007C117D /* Products */,\n"
        "\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n"
        "\t\t\t\tB3F2CE1A170B058972F850AD /* Pods */,\n"
        "\t\t\t\t0803A1C97BA7CB2B6A5D4047 /* Frameworks */,\n"
        "\t\t\t);",
    )
    t = t.replace(
        "\t\t\tchildren = (\n"
        "\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n"
        "\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n"
        "\t\t\t);",
        "\t\t\tchildren = (\n"
        "\t\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n"
        f"\t\t\t\t{I['file_appex']} /* WGExtension.appex */,\n"
        "\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n"
        "\t\t\t);",
    )
    t = t.replace(
        "/* End PBXNativeTarget section */",
        f"\t\t{I['target']} /* WGExtension */ = {{\n"
        f"\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {I['cfglist']} /* Build configuration list for PBXNativeTarget \"WGExtension\" */;\n"
        f"\t\t\tbuildPhases = (\n"
        f"\t\t\t\t{I['src_phase']} /* Sources */,\n"
        f"\t\t\t\t{I['fw_phase']} /* Frameworks */,\n"
        f"\t\t\t\t{I['res_phase']} /* Resources */,\n"
        f"\t\t\t);\n"
        f"\t\t\tbuildRules = (\n"
        f"\t\t\t);\n"
        f"\t\t\tdependencies = (\n"
        f"\t\t\t);\n"
        f"\t\t\tname = WGExtension;\n"
        f"\t\t\tpackageProductDependencies = (\n"
        f"\t\t\t\t{I['pkg_prod']} /* WireGuardKit */,\n"
        f"\t\t\t);\n"
        f"\t\t\tproductName = WGExtension;\n"
        f"\t\t\tproductReference = {I['file_appex']} /* WGExtension.appex */;\n"
        f"\t\t\tproductType = \"com.apple.product-type.app-extension\";\n"
        f"\t\t}};\n"
        "/* End PBXNativeTarget section */",
    )
    t = t.replace(
        "\t\t\tbuildPhases = (\n"
        "\t\t\t\tB9485736A688E12EB549CFA0 /* [CP] Check Pods Manifest.lock */,\n"
        "\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,\n"
        "\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,\n"
        "\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,\n"
        "\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n"
        "\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n"
        "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n"
        "\t\t\t\t06423DD868BA0D734BD02E3F /* [CP] Embed Pods Frameworks */,\n"
        "\t\t\t);\n"
        "\t\t\tbuildRules = (\n"
        "\t\t\t);\n"
        "\t\t\tdependencies = (\n"
        "\t\t\t);\n"
        "\t\t\tname = Runner;",
        "\t\t\tbuildPhases = (\n"
        "\t\t\t\tB9485736A688E12EB549CFA0 /* [CP] Check Pods Manifest.lock */,\n"
        "\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,\n"
        "\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,\n"
        "\t\t\t\t97C146EB1CF9000F007C117D /* Frameworks */,\n"
        "\t\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n"
        "\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n"
        f"\t\t\t\t{I['embed_phase']} /* Embed Foundation Extensions */,\n"
        "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n"
        "\t\t\t\t06423DD868BA0D734BD02E3F /* [CP] Embed Pods Frameworks */,\n"
        "\t\t\t);\n"
        "\t\t\tbuildRules = (\n"
        "\t\t\t);\n"
        "\t\t\tdependencies = (\n"
        f"\t\t\t\t{I['dep']} /* PBXTargetDependency */,\n"
        "\t\t\t);\n"
        "\t\t\tname = Runner;",
    )
    t = t.replace(
        "\t\t\t\t\t97C146ED1CF9000F007C117D = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n"
        "\t\t\t\t\t\tLastSwiftMigration = 1100;\n"
        "\t\t\t\t\t};",
        "\t\t\t\t\t97C146ED1CF9000F007C117D = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n"
        "\t\t\t\t\t\tLastSwiftMigration = 1100;\n"
        "\t\t\t\t\t\tProvisioningStyle = Automatic;\n"
        "\t\t\t\t\t};\n"
        f"\t\t\t\t\t{I['target']} = {{\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n"
        "\t\t\t\t\t\tProvisioningStyle = Automatic;\n"
        "\t\t\t\t\t};",
    )
    t = t.replace(
        "\t\t\tmainGroup = 97C146E51CF9000F007C117D;\n"
        "\t\t\tproductRefGroup = 97C146EF1CF9000F007C117D /* Products */;",
        "\t\t\tmainGroup = 97C146E51CF9000F007C117D;\n"
        "\t\t\tpackageReferences = (\n"
        f"\t\t\t\t{I['pkg_ref']} /* XCRemoteSwiftPackageReference \"wireguard-apple\" */,\n"
        "\t\t\t);\n"
        "\t\t\tproductRefGroup = 97C146EF1CF9000F007C117D /* Products */;",
    )
    t = t.replace(
        "\t\t\ttargets = (\n"
        "\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n"
        "\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n"
        "\t\t\t);",
        "\t\t\ttargets = (\n"
        "\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n"
        f"\t\t\t\t{I['target']} /* WGExtension */,\n"
        "\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n"
        "\t\t\t);",
    )
    t = t.replace(
        "/* End PBXResourcesBuildPhase section */",
        f"\t\t{I['res_phase']} /* Resources */ = {{\n"
        "\t\t\tisa = PBXResourcesBuildPhase;\n"
        "\t\t\tbuildActionMask = 2147483647;\n"
        "\t\t\tfiles = (\n"
        "\t\t\t);\n"
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        "\t\t};\n"
        "/* End PBXResourcesBuildPhase section */",
    )
    t = t.replace(
        "/* End PBXSourcesBuildPhase section */",
        f"\t\t{I['src_phase']} /* Sources */ = {{\n"
        "\t\t\tisa = PBXSourcesBuildPhase;\n"
        "\t\t\tbuildActionMask = 2147483647;\n"
        "\t\t\tfiles = (\n"
        f"\t\t\t\t{I['build_swift']} /* PacketTunnelProvider.swift in Sources */,\n"
        "\t\t\t);\n"
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        "\t\t};\n"
        "/* End PBXSourcesBuildPhase section */",
    )

    if "/* Begin PBXTargetDependency section */" in t:
        if I["dep"] not in t:
            t = t.replace(
                "/* End PBXTargetDependency section */",
                f"\t\t{I['dep']} /* PBXTargetDependency */ = {{\n"
                "\t\t\tisa = PBXTargetDependency;\n"
                f"\t\t\ttarget = {I['target']} /* WGExtension */;\n"
                f"\t\t\ttargetProxy = {I['proxy']} /* PBXContainerItemProxy */;\n"
                "\t\t};\n"
                "/* End PBXTargetDependency section */",
            )
    else:
        t = t.replace(
            "/* Begin PBXVariantGroup section */",
            "/* Begin PBXTargetDependency section */\n"
            f"\t\t{I['dep']} /* PBXTargetDependency */ = {{\n"
            "\t\t\tisa = PBXTargetDependency;\n"
            f"\t\t\ttarget = {I['target']} /* WGExtension */;\n"
            f"\t\t\ttargetProxy = {I['proxy']} /* PBXContainerItemProxy */;\n"
            "\t\t};\n"
            "/* End PBXTargetDependency section */\n\n"
            "/* Begin PBXVariantGroup section */",
        )

    # Inject TEAM into Runner configs
    t = t.replace(
        "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n"
        "\t\t\t\tCURRENT_PROJECT_VERSION",
        "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n"
        "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
        f"\t\t\t\tDEVELOPMENT_TEAM = {TEAM};\n"
        "\t\t\t\tCURRENT_PROJECT_VERSION",
    )

    settings = ext_build_settings("ios")
    cfgs = ""
    for key, name in [
        ("cfg_debug", "Debug"),
        ("cfg_release", "Release"),
        ("cfg_profile", "Profile"),
    ]:
        cfgs += (
            f"\t\t{I[key]} /* {name} */ = {{\n"
            f"\t\t\tisa = XCBuildConfiguration;\n"
            f"\t\t\tbuildSettings = {{{settings}\t\t\t}};\n"
            f"\t\t\tname = {name};\n"
            f"\t\t}};\n"
        )
    t = t.replace(
        "/* End XCBuildConfiguration section */",
        cfgs + "/* End XCBuildConfiguration section */",
    )
    t = t.replace(
        "/* End XCConfigurationList section */",
        f"\t\t{I['cfglist']} /* Build configuration list for PBXNativeTarget \"WGExtension\" */ = {{\n"
        "\t\t\tisa = XCConfigurationList;\n"
        "\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{I['cfg_debug']} /* Debug */,\n"
        f"\t\t\t\t{I['cfg_release']} /* Release */,\n"
        f"\t\t\t\t{I['cfg_profile']} /* Profile */,\n"
        "\t\t\t);\n"
        "\t\t\tdefaultConfigurationIsVisible = 0;\n"
        "\t\t\tdefaultConfigurationName = Release;\n"
        "\t\t};\n"
        "/* End XCConfigurationList section */",
    )
    spm = (
        "/* Begin XCRemoteSwiftPackageReference section */\n"
        f"\t\t{I['pkg_ref']} /* XCRemoteSwiftPackageReference \"wireguard-apple\" */ = {{\n"
        "\t\t\tisa = XCRemoteSwiftPackageReference;\n"
        '\t\t\trepositoryURL = "https://github.com/passepartoutvpn/wireguard-apple";\n'
        "\t\t\trequirement = {\n"
        "\t\t\t\tkind = upToNextMajorVersion;\n"
        "\t\t\t\tminimumVersion = 1.0.17;\n"
        "\t\t\t};\n"
        "\t\t};\n"
        "/* End XCRemoteSwiftPackageReference section */\n\n"
        "/* Begin XCSwiftPackageProductDependency section */\n"
        f"\t\t{I['pkg_prod']} /* WireGuardKit */ = {{\n"
        "\t\t\tisa = XCSwiftPackageProductDependency;\n"
        f"\t\t\tpackage = {I['pkg_ref']} /* XCRemoteSwiftPackageReference \"wireguard-apple\" */;\n"
        "\t\t\tproductName = WireGuardKit;\n"
        "\t\t};\n"
        "/* End XCSwiftPackageProductDependency section */\n"
    )
    t = t.replace(
        f"\t}};\n\trootObject = {root} /* Project object */;",
        f"\t}};\n{spm}\trootObject = {root} /* Project object */;",
    )
    path.write_text(t)
    print("patched iOS", path)


if __name__ == "__main__":
    patch_macos()
    patch_ios()
