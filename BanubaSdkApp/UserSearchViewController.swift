//
//  UserSearchViewController.swift
//  AgoraDemo
//
//  Created by Jonathan Fotland on 9/18/19.
//  Copyright © 2019 Jonathan Fotland. All rights reserved.
//

import UIKit
import Firebase

class UserSearchViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var userRef: DatabaseReference!
    var resultsArray = [[String:String]]()
    
    var handle: AuthStateDidChangeListenerHandle?
    var currentUser: User?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        userRef = Database.database().reference(withPath: "users")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            self.currentUser = user
            if user == nil {
                //Handle logout
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showChat" {
            if let friendID = sender as? String, let destination = segue.destination as? ChatViewController {
                destination.friendID = friendID
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath)
        
        if let userCell = cell as? UserTableViewCell {
            let userData = resultsArray[indexPath.row]
            userCell.displayName.text = userData["displayname"]
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let friendID = resultsArray[indexPath.row]["displayname"] {
            performSegue(withIdentifier: "showChat", sender: friendID)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        resultsArray.removeAll()
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if let searchText = searchBar.text?.lowercased(), searchText != "" {
            resultsArray.removeAll()
            queryText(searchText, inField: "username")
        } else {
            let alert = UIAlertController(title: "Error", message: "Please enter a username.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    func queryText(_ text: String, inField child: String) {
        userRef.queryOrdered(byChild: child)
            .queryStarting(atValue: text)
            .queryEnding(atValue: text+"\u{f8ff}")
            .observeSingleEvent(of: .value) { [weak self] (snapshot) in
                for case let item as DataSnapshot in snapshot.children {
                    //Don't show the current user in search results
                    if self?.currentUser?.uid == item.key {
                        continue
                    }
                    
                    if var itemData = item.value as? [String:String] {
                        itemData["uid"] = item.key
                        self?.resultsArray.append(itemData)
                    }
                }
                self?.tableView.reloadData()
        }
    }

}

