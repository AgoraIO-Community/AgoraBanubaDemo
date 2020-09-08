//
//  MainScreenViewController.swift
//  BanubaSdkApp
//
//  Created by Jonathan  Fotland on 8/3/20.
//  Copyright © 2020 Banuba. All rights reserved.
//

import UIKit
import FirebaseUI

class MainScreenViewController: UITabBarController {
    
    var handle: AuthStateDidChangeListenerHandle?
    var userRef: DatabaseReference!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        userRef = Database.database().reference(withPath: "users")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            if user == nil {
                self.showFUIAuthScreen()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

}

extension MainScreenViewController: FUIAuthDelegate {
    func showFUIAuthScreen() {
        let authUI = FUIAuth.defaultAuthUI()
        authUI?.delegate = self
        
        let providers: [FUIAuthProvider] = [
            FUIGoogleAuth(),
            FUIEmailAuth()
        ]
        authUI?.providers = providers
        
        if let authViewController = authUI?.authViewController() {
            navigationController?.pushViewController(authViewController, animated: false)
        }
    }
    
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        } else {
            
            //Save the user to our list of users.
            if let user = authDataResult?.user {
                userRef.child(user.uid).setValue(["username" : user.displayName?.lowercased(),
                                                             "displayname" : user.displayName,
                                                             "email": user.email])
            }
        }
    }
}

