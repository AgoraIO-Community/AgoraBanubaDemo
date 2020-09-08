//
//  CustomAgoraViewController.swift
//  BanubaSdkApp
//
//  Created by Jonathan  Fotland on 8/20/20.
//  Copyright © 2020 Banuba. All rights reserved.
//

import UIKit
import AgoraUIKit
import AgoraRtmKit
import FirebaseAuth

class CustomAgoraViewController: AgoraVideoViewController, UITableViewDelegate, UITableViewDataSource, AgoraRtmDelegate {

    var chatTableView: UITableView!
    
    var agoraRtm: AgoraRtmKit?
    var rtmChannelName: String?
    var rtmChannel: AgoraRtmChannel?
    var bottomConstraint: NSLayoutConstraint?
    
    var handle: AuthStateDidChangeListenerHandle?
    var currentUser: User?
    
    var messageList: [String] = []
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            self.currentUser = user
            if let user = user, let channelName = self.rtmChannelName {
                self.agoraRtm = AgoraRtmKit.init(appId: "YOUR_APP_ID_HERE", delegate: self)
                self.agoraRtm?.login(byToken: nil, user: user.displayName ?? user.uid) { (error) in
                    if error != .ok {
                        print("Error logging in: ", error.rawValue)
                    } else {
                        self.rtmChannel = self.agoraRtm?.createChannel(withId: channelName, delegate: self)
                        self.rtmChannel?.join(completion: { (error) in
                            if error != .channelErrorOk {
                                print("Error joining channel: ", error.rawValue)
                            }
                        })
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        if let channel = self.rtmChannel {
            channel.leave(completion: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        chatTableView = UITableView(frame: .zero)
        view.addSubview(chatTableView)
        
        chatTableView.delegate = self
        chatTableView.dataSource = self
        chatTableView.backgroundColor = UIColor.clear
        
        chatTableView.translatesAutoresizingMaskIntoConstraints = false

        chatTableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        chatTableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4).isActive = true
        chatTableView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5).isActive = true
        
        chatTableView.register(UITableViewCell.self, forCellReuseIdentifier: "chatCell")
        chatTableView.keyboardDismissMode = .onDrag
        collectionView.keyboardDismissMode = .interactive
        
        let chatField = UITextField(frame: .zero)
        chatField.delegate = self
        chatField.backgroundColor = UIColor.white

        view.addSubview(chatField)
        chatField.translatesAutoresizingMaskIntoConstraints = false

        chatField.topAnchor.constraint(equalTo: chatTableView.bottomAnchor).isActive = true
        chatField.leftAnchor.constraint(equalTo: chatTableView.leftAnchor).isActive = true
        chatField.widthAnchor.constraint(equalTo: chatTableView.widthAnchor).isActive = true
        chatField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        bottomConstraint = view.bottomAnchor.constraint(equalTo: chatField.bottomAnchor, constant: 110)
        bottomConstraint?.isActive = true

        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messageList.count
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "chatCell", for: indexPath)

        //if let chatCell = cell as? ChatTableViewCell {
        let message = messageList[indexPath.row]
        cell.textLabel?.text = message
        cell.textLabel?.numberOfLines = 0
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = .systemBlue
        //}

        return cell
    }
    
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        guard let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        let keyboardFrame = keyboardSize.cgRectValue
        
        bottomConstraint?.constant = 20 + keyboardFrame.height
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        bottomConstraint?.constant = 110
    }
}

extension CustomAgoraViewController: UITextFieldDelegate {
    func addMessage(user: String, message: String) {
        let message = "\(user): \(message)"
        messageList.append(message)
        let indexPath = IndexPath(row: self.messageList.count-1, section: 0)
        self.chatTableView.insertRows(at: [indexPath], with: UITableView.RowAnimation.automatic)
        self.chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text, text != "" {
            rtmChannel?.send(AgoraRtmMessage(text: text), completion: { (error) in
                if error != .errorOk {
                    print("Failed to send message: ", error)
                } else {
                    self.addMessage(user: self.currentUser!.displayName ?? self.currentUser!.uid, message: text)
                }
            })
            textField.text = ""
        }
        return true
    }
}

extension CustomAgoraViewController: AgoraRtmChannelDelegate {
    func channel(_ channel: AgoraRtmChannel, messageReceived message: AgoraRtmMessage, from member: AgoraRtmMember) {
        addMessage(user: member.userId, message: message.text)
    }
    
    func channel(_ channel: AgoraRtmChannel, memberJoined member: AgoraRtmMember) {
        print("Joined RTM channel: \(member)")
    }
    
    func channel(_ channel: AgoraRtmChannel, memberLeft member: AgoraRtmMember) {
        print("Left RTM channel: \(member)")
    }
}
