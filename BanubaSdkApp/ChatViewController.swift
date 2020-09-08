//
//  ChatViewController.swift
//  AgoraDemo
//
//  Created by Jonathan  Fotland on 6/11/20.
//  Copyright © 2020 Jonathan Fotland. All rights reserved.
//

import UIKit
import AgoraRtmKit
import Firebase

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    var agoraRtm: AgoraRtmKit?
    var friendID: String?
    
    var handle: AuthStateDidChangeListenerHandle?
    var currentUser: User?
    
    var messageList: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        textField.becomeFirstResponder()
        
        agoraRtm = AgoraRtmKit(appId: "YOUR_APP_ID_HERE", delegate: self)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "chatCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            self.currentUser = user
            if let username = user?.displayName, let friendName = self.friendID {
                self.navigationItem.title = friendName
                self.agoraRtm?.login(byToken: nil, user: username, completion: { (error) in
                    if error != .ok {
                        print("error logging in")
                    }
                })
            } else {
                //Handle logout
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        let keyboardFrame = keyboardSize.cgRectValue
        
        bottomConstraint.constant = 20 + keyboardFrame.height
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        bottomConstraint.constant = 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messageList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "chatCell", for: indexPath)
        
        let message = messageList[indexPath.row]
        cell.textLabel?.text = message
        cell.textLabel?.numberOfLines = 0
        
        
        return cell
    }
    
    func addMessage(user: String, message: String) {
        let message = "\(user): \(message)"
        messageList.append(message)
        let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
        self.tableView.insertRows(at: [indexPath], with: UITableView.RowAnimation.automatic)
        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text, text != "" {
            let option = AgoraRtmSendMessageOptions()
            option.enableOfflineMessaging = true
            agoraRtm?.send(AgoraRtmMessage(text: text), toPeer: friendID!, sendMessageOptions: option, completion: { (error) in
                if error == .ok || error == .cachedByServer {
                    self.addMessage(user: self.currentUser!.displayName ?? self.currentUser!.uid, message: text)
                } else {
                    print("Failed to send message: ", error)
                }
            })
            textField.text = ""
        }
        return true
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension ChatViewController: AgoraRtmDelegate {
    func rtmKit(_ kit: AgoraRtmKit, messageReceived message: AgoraRtmMessage, fromPeer peerId: String) {
        if peerId == friendID {
            addMessage(user: peerId, message: message.text)
        }
    }
}
