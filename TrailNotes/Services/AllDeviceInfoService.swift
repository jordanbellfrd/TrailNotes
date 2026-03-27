import Foundation
import UIKit
import CoreTelephony
import SystemConfiguration
import Network
import SystemConfiguration.CaptiveNetwork

class AllDeviceInfoService {
    static let shared = AllDeviceInfoService()
    private let networkInfo = CTTelephonyNetworkInfo()
    
    private let vpnProtocolsKeysIdentifiers = [
        "tap", "tun", "ppp", "ipsec", "utun"
    ]
    
    private init() {}
    
    func getCarrierName() -> String? {
        if let CTTelephonyNetworkInfoClass = NSClassFromString("CTTelephonyNetworkInfo") {
            if let instance = CTTelephonyNetworkInfoClass.alloc() as? NSObject {
                if let subscriberCellularProvider = instance.value(forKey: "subscriberCellularProvider") as? NSObject {
                    if let carrierName = subscriberCellularProvider.value(forKey: "carrierName") as? String {
                        return carrierName
                    }
                }
            }
        }
        return nil
    }
    
    func getCarrierMCC() -> String? {
        if let CTTelephonyNetworkInfoClass = NSClassFromString("CTTelephonyNetworkInfo") {
            if let instance = CTTelephonyNetworkInfoClass.alloc() as? NSObject {
                if let subscriberCellularProvider = instance.value(forKey: "subscriberCellularProvider") as? NSObject {
                    if let mobileCountryCode = subscriberCellularProvider.value(forKey: "mobileCountryCode") as? String {
                        return mobileCountryCode
                    }
                }
            }
        }
        return nil
    }
    
    func getISP() -> String? {
        return getCarrierName()
    }
    
    func getNetworkType() -> String {
        guard let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "www.google.com") else {
            return "unknown"
        }

        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)

        let isReachable = flags.contains(.reachable)
        let isWWAN = flags.contains(.isWWAN)

        if isReachable {
            if isWWAN {
                return "MOBILE"
            } else {
                return "WIFI"
            }
        } else {
            return "unknown"
        }
    }
    
    func getLocalIP() -> String {
        return getIpAddress() ?? "unknown"
    }
    
    private func getIpAddress() -> String? {
        var address : String?
        
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            

            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                

                let name = String(cString: interface.ifa_name)
                if  name == "en0" {

                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                } else if (name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3") {

                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(1), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    func getProxyIP() -> String? {
        if let proxySettingsUnmanaged = CFNetworkCopySystemProxySettings() {
            let proxySettings = proxySettingsUnmanaged.takeRetainedValue()
            if let dict = proxySettings as? [String: AnyObject],
               let value = dict[kCFNetworkProxiesHTTPProxy as String] as? String {
                return value
            }
        }
        return nil
    }
    
    func isVpnActive() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else { return false }
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        guard let keys = nsDict["__SCOPED__"] as? NSDictionary,
            let allKeys = keys.allKeys as? [String] else { return false }

        for key in allKeys {
            for protocolId in vpnProtocolsKeysIdentifiers
                where key.starts(with: protocolId) {
                return true
            }
        }
        return false
    }
    
    func getCPUType() -> String {
        #if targetEnvironment(simulator)
        return ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Unknown"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #endif
    }
    
    func getBuild() -> String? {
        if let build = SysctlKey("kern.osversion") {
            return "Build/\(build)"
        }
        return nil
    }
    
    private func SysctlKey(_ key: String) -> String? {
        var bufferSize = 0
        sysctlbyname(key, nil, &bufferSize, nil, 0)
        var buffer = [CChar](repeating: 0, count: Int(bufferSize))
        let status = sysctlbyname(key, &buffer, &bufferSize, nil, 0)
        if status != 0 {
            return nil
        }
        return String(cString:buffer, encoding: String.Encoding.utf8)
    }
    
    func getDevice() -> String {
        return getCPUType()
    }
    
    func getOSAndVersion() -> String {
        return "iOS \(UIDevice.current.systemVersion)"
    }
    
    func getOSName() -> String {
        return "iOS"
    }
    
    func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    func getPlatform() -> String {
        return "ios"
    }
    
    func getSDKPlatform() -> String {
        return "ios"
    }
    
    func getAppVersionRaw() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
    }
    
    func getInstallDate() -> Int64 {
        do {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            if let firstPath = paths.first {
                let attributes = try FileManager.default.attributesOfItem(atPath: firstPath.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    return Int64(creationDate.timeIntervalSince1970 * 1000)
                }
            }
        } catch {
            logPrint("❌ Error getting install date: \(error)")
        }
        
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    private func formatDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
    
}
