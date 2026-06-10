import Foundation
import ServiceManagement

class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()
    
    @Published var isEnabled: Bool = false {
        didSet {
            updateLaunchAtLogin(enabled: isEnabled)
        }
    }
    
    private init() {
        if #available(macOS 13.0, *) {
            self.isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
    
    func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled {
                    do {
                        try service.register()
                    } catch {
                        print("LaunchAtLoginService: Failed to register: \(error)")
                    }
                }
            } else {
                if service.status == .enabled {
                    service.unregister { error in
                        if let error = error {
                            print("LaunchAtLoginService: Failed to unregister: \(error)")
                        }
                    }
                }
            }
        }
    }
}
