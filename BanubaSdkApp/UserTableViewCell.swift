//
//  UserTableViewCell.swift
//  AgoraDemo
//
//  Created by Jonathan Fotland on 9/18/19.
//  Copyright © 2019 Jonathan Fotland. All rights reserved.
//

import UIKit

class UserTableViewCell: UITableViewCell {

    @IBOutlet weak var displayName: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
