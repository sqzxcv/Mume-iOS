//
//  PaddingLabel.swift
//  Potatso
//
//  Created by LEI on 7/17/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation

class PaddingLabel: UILabel {

    var padding: UIEdgeInsets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        let newRect = rect.inset(by: padding)
        super.drawText(in: newRect)
    }

    override var intrinsicContentSize : CGSize {
        var s = super.intrinsicContentSize
        s.height += padding.top + padding.bottom
        s.width += padding.left + padding.right
        return s
    }

}
