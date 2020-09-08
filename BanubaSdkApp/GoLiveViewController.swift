//
//  GoLiveViewController.swift
//  BanubaSdkApp
//
//  Created by Jonathan  Fotland on 8/3/20.
//  Copyright © 2020 Banuba. All rights reserved.
//

import UIKit
import FirebaseUI
import AgoraUIKit

class GoLiveViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var handle: AuthStateDidChangeListenerHandle?
    var userRef: DatabaseReference!
    var liveRef: DatabaseReference!
    var currentUser: User?
    
    var liveUsers = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        userRef = Database.database().reference(withPath: "users")
        liveRef = Database.database().reference(withPath: "live")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            if let user = user {
                self.currentUser = user
                self.liveRef.observe(.childAdded) { (snapshot) in
                    self.liveUsers.append(snapshot.key)
                    self.tableView.insertRows(at: [IndexPath(row: self.liveUsers.count-1, section: 0)], with: .automatic)
                }
                self.liveRef.observe(.childRemoved) { (snapshot) in
                    let name = snapshot.key
                    if let index = self.liveUsers.firstIndex(of: name) {
                        self.liveUsers.remove(at: index)
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                }
            } else {
                self.showFUIAuthScreen()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
            liveUsers.removeAll()
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return liveUsers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "liveCell", for: indexPath)
        
        if let liveCell = cell as? LiveTableViewCell {
            liveCell.nameLabel.text = liveUsers[indexPath.row]
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let userName = liveUsers[indexPath.row]
        
        let agoraAudienceView = CustomAgoraViewController(appID: "YOUR_APP_ID_HERE", token: nil, channel: userName)
        agoraAudienceView.setMaxStreams(streams: 1)
        agoraAudienceView.setIsAudience()
        agoraAudienceView.hideVideoMute()
        agoraAudienceView.hideAudioMute()
        agoraAudienceView.hideSwitchCamera()
        agoraAudienceView.controlOffset = 60
        
        agoraAudienceView.rtmChannelName = userName
        
        navigationController?.pushViewController(agoraAudienceView, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
    @IBAction func didTapGoLive(_ sender: Any) {
        if let userName = currentUser?.displayName {
            liveRef.child(userName).setValue("true")
            performSegue(withIdentifier: "GoLive", sender: userName)
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "GoLive" {
            if let banubaView = segue.destination as? ViewController {
                banubaView.roomName = sender as? String
            }
        }
    }
}

extension GoLiveViewController: FUIAuthDelegate {
    func showFUIAuthScreen() {
        let authUI = FUIAuth.defaultAuthUI()
        authUI?.delegate = self

        let providers: [FUIAuthProvider] = [
            FUIGoogleAuth(),
            FUIEmailAuth()
        ]
        authUI?.providers = providers
        authUI?.shouldHideCancelButton = true

        if let authViewController = authUI?.authViewController() {
            authViewController.modalPresentationStyle = .fullScreen
            navigationController?.present(authViewController, animated: false, completion: nil)
            //navigationController?.pushViewController(authViewController, animated: false)
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
