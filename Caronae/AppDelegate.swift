import UIKit
import SVProgressHUD
import Alamofire
import AlamofireNetworkActivityIndicator
import AudioToolbox
import FBSDKCoreKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var beepSound: SystemSoundID = 0
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.setFadeOutAnimationDuration(0)
        SVProgressHUD.setMinimumSize(CGSize(width: 100, height: 100))
        
        NetworkActivityIndicatorManager.shared.isEnabled = true
        
        configureRealm()
        configureFirebase()
        configureFacebook(WithLaunchOptions: launchOptions)
        
        // Prepare beepSound for notifications while app is in foreground
        if let soundURL = Bundle.main.url(forResource: "beep", withExtension: "wav") {
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &beepSound)
        }
        
        // Load the home screen if the user is signed in
        if UserService.instance.user != nil {
            window?.rootViewController = TabBarController.instance()
            window?.makeKeyAndVisible()
            registerForNotifications()
            checkIfUserNeedsToFinishProfile()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateUser(notification:)), name: .CaronaeDidUpdateUser, object: nil)
        
        // Update application badge number and listen to notification updates
        updateApplicationBadgeNumber()
        NotificationCenter.default.addObserver(self, selector: #selector(updateApplicationBadgeNumber), name: .CaronaeDidUpdateNotifications, object: nil)
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if UserService.instance.user != nil {
            updateUserRidesAndPlaces()
        }
        
        // Handle any deeplink
        deepLinkManager.checkDeepLink()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    @objc func didUpdateUser(notification: NSNotification) {
        if UserService.instance.user != nil {
            registerForNotifications()
            updateUserRidesAndPlaces()
            checkIfUserNeedsToFinishProfile()
        } else {
            // Check if the logout was forced by the server
            if let signOutRequired = notification.userInfo?[CaronaeSignOutRequiredKey] as? Bool, signOutRequired {
                CaronaeAlertController.presentOkAlert(withTitle: "Erro de autorização",
                                                      message: """
                                                               Ocorreu um erro autenticando seu usuário.
                                                               Sua chave de acesso pode ter sido redefinida ou suspensa.\n\n
                                                               Para sua segurança, você será levado à tela de login.
                                                               """,
                                                      handler: {
                                                        self.displayAuthenticationScreen()
                })
            } else {
                displayAuthenticationScreen()
            }
            
            disconnectFromFcm()
        }
    }
    
    func checkIfUserNeedsToFinishProfile() {
        if let user = UserService.instance.user, user.isProfileIncomplete {
            DispatchQueue.main.async {
                self.displayFinishProfileScreen()
            }
        }
    }
    
    func displayAuthenticationScreen() {
        let authViewController = LoginViewController.viewController()
        UIApplication.shared.keyWindow?.replaceViewController(with: authViewController)
    }
    
    func displayFinishProfileScreen() {
        let rootViewController = UIApplication.shared.keyWindow?.rootViewController
        let welcomeViewController = WelcomeViewController()
        let welcomeNavigationController = UINavigationController(rootViewController: welcomeViewController)
        welcomeNavigationController.modalTransitionStyle = .coverVertical
        welcomeNavigationController.modalPresentationStyle = .overCurrentContext
        rootViewController?.present(welcomeNavigationController, animated: true, completion: nil)
    }
    
    func updateUserRidesAndPlaces() {
        RideService.instance.updateMyRides(success: {
            NSLog("My rides updated")
        }, error: { error in
            NSLog("Error updating my rides (\(error.localizedDescription))")
        })
        
        PlaceService.instance.updatePlaces(success: {
            NSLog("Places updated")
        }, error: { error in
            NSLog("Error updating places (\(error.localizedDescription))")
        })
    }
    
    
    // MARK: Facebook SDK
    
    func configureFacebook(WithLaunchOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        FBSDKApplicationDelegate.sharedInstance().application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)
        
        NotificationCenter.default.addObserver(self, selector: #selector(FBTokenChanged(notification:)), name: .FBSDKAccessTokenDidChange, object: nil)
    }
    
    @objc func FBTokenChanged(notification: NSNotification) {
        guard let token = FBSDKAccessToken.current() else {
            NSLog("User has logged out from Facebook.")
            return
        }
        
        NSLog("Facebook Access Token did change.")
        
        var fbID = String()
        if notification.userInfo?[FBSDKAccessTokenDidChangeUserIDKey] != nil {
            if let userID = token.userID {
                NSLog("Facebook has loogged in with Facebook ID %@.", userID)
                fbID = userID
            }
        }
        
        UserService.instance.updateFacebookID(fbID, success: {
            NSLog("Updated user's Facebook credentials on server.")
        }, error: { error in
            NSLog("Error updating user's Facebook credentials on server: %@", error.localizedDescription)
        })
    }
    
    
    // MARK: Deeplinks
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return FBSDKApplicationDelegate.sharedInstance().application(application, open: url, options: options) ||
            deepLinkManager.handleDeepLink(url: url)
    }
    
    
    // MARK: Universal Links
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL else {
                return false
        }
        return deepLinkManager.handleUniversalLink(url: url)
    }
}
