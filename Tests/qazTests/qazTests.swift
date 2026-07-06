import Testing
@testable import qaz

private func asset(name: String, size: Int = 1_000_000) -> Asset {
    Asset(id: 1, name: name, browserDownloadURL: "", digest: nil, size: size, contentType: "application/octet-stream")
}

// MARK: - platformHint

struct PlatformHintTests {
    @Test func macOSByDarwin() {
        #expect(asset(name: "app_darwin_arm64.tar.gz").platformHint == "macOS")
    }

    @Test func macOSByMacos() {
        #expect(asset(name: "app_macos.dmg").platformHint == "macOS")
    }

    @Test func macOSByOsx() {
        #expect(asset(name: "app_osx.zip").platformHint == "macOS")
    }

    @Test func macOSByDmgSuffix() {
        #expect(asset(name: "something.dmg").platformHint == "macOS")
    }

    @Test func macOSByAppZipSuffix() {
        #expect(asset(name: "something.app.zip").platformHint == "macOS")
    }

    @Test func linuxByLinux() {
        #expect(asset(name: "app_linux_x86_64.tar.gz").platformHint == "Linux")
    }

    @Test func linuxByUbuntu() {
        #expect(asset(name: "app_ubuntu_amd64.deb").platformHint == "Linux")
    }

    @Test func linuxByDebian() {
        #expect(asset(name: "app_debian_arm64.deb").platformHint == "Linux")
    }

    @Test func linuxByDebSuffix() {
        #expect(asset(name: "something.deb").platformHint == "Linux")
    }

    @Test func linuxByRpmSuffix() {
        #expect(asset(name: "something.rpm").platformHint == "Linux")
    }

    @Test func linuxByPkgTarZstSuffix() {
        #expect(asset(name: "something.pkg.tar.zst").platformHint == "Linux")
    }

    @Test func windowsByWin() {
        #expect(asset(name: "app_win_x64.zip").platformHint == "Windows")
    }

    @Test func windowsByWindows() {
        #expect(asset(name: "app_windows_amd64.zip").platformHint == "Windows")
    }

    @Test func bsdByFreebsd() {
        #expect(asset(name: "app_freebsd_arm64.tar.gz").platformHint == "BSD")
    }

    @Test func bsdByOpenbsd() {
        #expect(asset(name: "app_openbsd_x86_64.tar.gz").platformHint == "BSD")
    }

    @Test func bsdByNetbsd() {
        #expect(asset(name: "app_netbsd_x86_64.tar.gz").platformHint == "BSD")
    }

    @Test func emptyForUnknown() {
        #expect(asset(name: "checksums.txt").platformHint == "")
    }

    @Test func caseInsensitive() {
        #expect(asset(name: "App_Darwin_Arm64.tar.gz").platformHint == "macOS")
        #expect(asset(name: "App_LINUX_x86_64.tar.gz").platformHint == "Linux")
        #expect(asset(name: "App_WINDOWS_amd64.zip").platformHint == "Windows")
        #expect(asset(name: "App_FreeBSD_arm64.tar.gz").platformHint == "BSD")
    }
}

// MARK: - architectureHint

struct ArchitectureHintTests {
    @Test func arm64() {
        #expect(asset(name: "app_darwin_arm64.tar.gz").architectureHint == "arm64")
    }

    @Test func aarch64() {
        #expect(asset(name: "app_linux_aarch64.tar.gz").architectureHint == "arm64")
    }

    @Test func x86_64() {
        #expect(asset(name: "app_linux_x86_64.tar.gz").architectureHint == "x86_64")
    }

    @Test func amd64() {
        #expect(asset(name: "app_windows_amd64.zip").architectureHint == "x86_64")
    }

    @Test func x64() {
        #expect(asset(name: "app_win_x64.zip").architectureHint == "x86_64")
    }

    @Test func armv6() {
        #expect(asset(name: "app_linux_armv6.tar.gz").architectureHint == "arm")
    }

    @Test func armv7() {
        #expect(asset(name: "app_linux_armv7.tar.gz").architectureHint == "arm")
    }

    @Test func armhf() {
        #expect(asset(name: "app_linux_armhf.tar.gz").architectureHint == "arm")
    }

    @Test func thirtyTwoBit() {
        #expect(asset(name: "app_linux_32-bit.tar.gz").architectureHint == "x86")
    }

    @Test func i386() {
        #expect(asset(name: "app_linux_i386.tar.gz").architectureHint == "x86")
    }

    @Test func i686() {
        #expect(asset(name: "app_linux_i686.tar.gz").architectureHint == "x86")
    }

    @Test func emptyForUnknown() {
        #expect(asset(name: "checksums.txt").architectureHint == "")
    }

    @Test func caseInsensitive() {
        #expect(asset(name: "app_AARCH64.tar.gz").architectureHint == "arm64")
        #expect(asset(name: "app_AMD64.zip").architectureHint == "x86_64")
        #expect(asset(name: "app_ARMV7.tar.gz").architectureHint == "arm")
        #expect(asset(name: "app_I386.tar.gz").architectureHint == "x86")
    }
}

// MARK: - isRecommended

struct IsRecommendedTests {
    @Test func tooSmall() {
        #expect(asset(name: "app_darwin_arm64.tar.gz", size: 99_999).isRecommended == false)
    }

    @Test func exactlyMinimumSize() {
        #expect(asset(name: "app_darwin_arm64.tar.gz", size: 100_000).isRecommended == true)
    }

    @Test func noPlatformNoArch() {
        #expect(asset(name: "checksums.txt", size: 500_000).isRecommended == false)
    }

    @Test func platformOnlyNoArch() {
        #expect(asset(name: "something.dmg", size: 500_000).isRecommended == true)
    }

    @Test func archOnlyNoPlatform() {
        #expect(asset(name: "app_arm64.tar.gz", size: 500_000).isRecommended == true)
    }

    @Test func darwinArm64OnMacOS() {
        #expect(asset(name: "lazygit_0.63.0_darwin_arm64.tar.gz").isRecommended == true)
    }

    @Test func darwinX86_64OnMacOS() {
        #expect(asset(name: "lazygit_0.63.0_darwin_x86_64.tar.gz").isRecommended == false)
    }

    @Test func linuxNotRecommendedOnMacOS() {
        #expect(asset(name: "lazygit_0.63.0_linux_arm64.tar.gz").isRecommended == false)
    }

    @Test func windowsNotRecommendedOnMacOS() {
        #expect(asset(name: "lazygit_0.63.0_windows_arm64.zip").isRecommended == false)
    }

    @Test func bsdNotRecommendedOnMacOS() {
        #expect(asset(name: "lazygit_0.63.0_freebsd_arm64.tar.gz").isRecommended == false)
    }

    @Test func freebsdAllArchitecturesNotRecommendedOnMacOS() {
        #expect(asset(name: "lazygit_0.63.0_freebsd_32-bit.tar.gz").isRecommended == false)
        #expect(asset(name: "lazygit_0.63.0_freebsd_armv6.tar.gz").isRecommended == false)
        #expect(asset(name: "lazygit_0.63.0_freebsd_x86_64.tar.gz").isRecommended == false)
    }
}
