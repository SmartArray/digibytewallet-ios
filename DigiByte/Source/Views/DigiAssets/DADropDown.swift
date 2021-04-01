//
//  DADropDown.swift
//  DigiByte
//
//  Created by Yoshi Jaeger on 05.12.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import UIKit
import Kingfisher

class DADropDown: UIView {
    let imageView = UIImageView()
    let titleLabel = UILabel(font: UIFont.da.customBold(size: 14), color: .white)
    let downImg = UIImageView(image: UIImage(named: "da_sort_down")?.withRenderingMode(.alwaysTemplate))
    
    static let imageSize: CGFloat = 22.0
    
    init() {
        super.init(frame: .zero)
        
        addSubviews()
        addConstraints()
        addEvents()
        
        setStyle()
    }
    
    private func defaultContent() {
        imageView.image = UIImage(named: "digiassets_small")
        imageView.alpha = 0.7
        
        titleLabel.textColor = .gray
        titleLabel.text = S.Assets.select
    }
    
    func setContent(asset: AssetModel?) {
        guard let asset = asset else { defaultContent(); return }
        
        imageView.alpha = 1.0
        titleLabel.textColor = .white
        
        titleLabel.text = asset.getAssetName()
        
        if let urlStr = asset.getImage()?.url, let url = URL(string: urlStr) {
            imageView.kf.setImage(with: url, placeholder: nil, options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: DADropDown.imageSize, height: DADropDown.imageSize) )),
                .scaleFactor(UIScreen.main.scale),
                .cacheOriginalImage
            ])
        } else {
            imageView.image = UIImage(named: "digiassets_small")
        }
    }
    
    private func addSubviews() {
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(downImg)
    }
    
    private func addConstraints() {
        heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        imageView.constrain([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0),
            imageView.widthAnchor.constraint(equalToConstant: DADropDown.imageSize),
            imageView.heightAnchor.constraint(equalToConstant: DADropDown.imageSize),
        ])
        
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        
        downImg.constrain([
            downImg.centerYAnchor.constraint(equalTo: centerYAnchor),
            downImg.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            downImg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }
    
    private func addEvents() {
        
    }
    
    private func setStyle() {
        layer.cornerRadius = 6
        layer.masksToBounds = true
        backgroundColor = UIColor(red: 67 / 255, green: 68 / 255, blue: 90 / 255, alpha: 1.0)
        
        imageView.contentMode = .scaleAspectFit
        
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .left
        titleLabel.lineBreakMode = .byWordWrapping
        
        downImg.tintColor = UIColor(red: 248 / 255, green: 156 / 255, blue: 78 / 255, alpha: 1.0) // 248 156 78
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
