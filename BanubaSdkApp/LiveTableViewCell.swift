//
//  LiveTableViewCell.swift
//  BanubaSdkApp
//
//  Created by Jonathan  Fotland on 8/3/20.
//  Copyright © 2020 Banuba. All rights reserved.
//

import UIKit

class LiveTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
