/*

 The MIT License (MIT)
 Copyright (c) 2017-2018 Dalton Hinterscher

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
 ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH
 THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

import UIKit
import SnapKit

import MarqueeLabel

@objcMembers
open class StatusBarNotificationBanner: BaseNotificationBanner {

    /// Height of the message strip itself, matching the classic 20pt status bar.
    private let messageStripHeight: CGFloat = 20.0

    /// Top constraint of the title. Updated when status-bar clearance changes.
    private var titleTopConstraint: Constraint?

    /// Last title inset applied, so layout does not rewrite an unchanged constraint.
    private var appliedTitleTopOffset: CGFloat = 0

    public override var bannerHeight: CGFloat {
        get {
            if let customBannerHeight = customBannerHeight {
                return customBannerHeight
            } else if let safeAreaTop = safeAreaClearingTopInset() {
                // The message sits below the safe area. The extra height is the
                // colored region that fills in behind the status bar.
                return safeAreaTop + messageStripHeight
            } else if shouldAdjustForDynamicIsland() {
                return 70.0
            } else if shouldAdjustForNotchFeaturedIphone() {
                return 50.0
            } else {
                return messageStripHeight + heightAdjustment
            }
        } set {
            customBannerHeight = newValue
        }
    }

    /// Grows the spring spacer so the content view starts at the safe area.
    /// The spacer is the same color as the banner, which keeps one continuous band
    /// behind the clock and status icons. Home-button phones keep the base spacer.
    override func spacerViewHeight() -> CGFloat {
        if let safeAreaTop = safeAreaClearingTopInset() {
            return safeAreaTop + spacerViewDefaultOffset
        }
        return super.spacerViewHeight()
    }

    override init(style: BannerStyle, colors: BannerColorsProtocol? = nil) {
        super.init(style: style, colors: colors)

        titleLabel = MarqueeLabel()
        (titleLabel as! MarqueeLabel).animationDelay = 2
        (titleLabel as! MarqueeLabel).type = .leftRight
        titleLabel!.font = UIFont.systemFont(ofSize: 12.5, weight: UIFont.Weight.bold)
        titleLabel!.textAlignment = .center
        titleLabel!.textColor = .white
        contentView.addSubview(titleLabel!)

        let topOffset = titleTopOffset(position: bannerPosition)
        appliedTitleTopOffset = topOffset
        titleLabel!.snp.makeConstraints { (make) in
            self.titleTopConstraint = make.top.equalToSuperview().offset(topOffset).constraint
            make.left.equalToSuperview().offset(5)
            make.right.equalToSuperview().offset(-5)
            make.bottom.equalToSuperview()
        }

        updateMarqueeLabelsDurations()
    }

    public convenience init(
        title: String,
        style: BannerStyle = .info,
        colors: BannerColorsProtocol? = nil
    ) {
        self.init(style: style, colors: colors)
        titleLabel!.text = title
    }

    public convenience init(
        attributedTitle: NSAttributedString,
        style: BannerStyle = .info,
        colors: BannerColorsProtocol? = nil
    ) {
        self.init(style: style, colors: colors)
        titleLabel!.attributedText = attributedTitle
    }

    public init(customView: UIView) {
        super.init(style: .customView)
        self.customView = customView
        
        contentView.addSubview(customView)
        customView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }

        spacerView.backgroundColor = customView.backgroundColor
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func show(
        placeOnQueue: Bool,
        queuePosition: QueuePosition,
        bannerPosition: BannerPosition
    ) {
        // super.show stores bannerPosition before it measures height. Match the
        // title inset to that position first so the strip and the band agree.
        if !isDisplaying {
            applyTitleTopOffsetIfNeeded(position: bannerPosition)
        }
        super.show(
            placeOnQueue: placeOnQueue,
            queuePosition: queuePosition,
            bannerPosition: bannerPosition
        )
    }

    open override func layoutSubviews() {
        let didChange = applyTitleTopOffsetIfNeeded(position: bannerPosition)
        super.layoutSubviews()
        if didChange {
            setNeedsLayout()
        }
    }

    /// Safe-area top inset when this banner is painted under the status bar and
    /// the existing layout would still place the message on top of the clock.
    /// Nil keeps the historical layout: home-button phones, iPad, landscape,
    /// banners shown under a navigation bar, bottom banners, and custom heights.
    private func safeAreaClearingTopInset(position: BannerPosition? = nil) -> CGFloat? {
        guard customBannerHeight == nil else { return nil }

        let position = position ?? bannerPosition
        guard position == .top else { return nil }

        let navigationBarIsHidden = parentViewController?.navigationController?.isNavigationBarHidden ?? true
        guard navigationBarIsHidden else { return nil }

        let safeTop = interfaceSafeAreaTop()
        // iPhone X is the smallest notch inset (44pt). Home-button phones are
        // 20pt and iPad is 24pt, and both already clear their status bar.
        guard safeTop >= 44 else { return nil }

        let existingTextTop = super.spacerViewHeight() - spacerViewDefaultOffset + heightAdjustment
        guard safeTop > existingTextTop else { return nil }
        return safeTop
    }

    private func titleTopOffset(position: BannerPosition) -> CGFloat {
        if safeAreaClearingTopInset(position: position) != nil {
            return 0
        }
        return heightAdjustment
    }

    @discardableResult
    private func applyTitleTopOffsetIfNeeded(position: BannerPosition) -> Bool {
        guard let titleTopConstraint = titleTopConstraint else { return false }
        let offset = titleTopOffset(position: position)
        guard offset != appliedTitleTopOffset else { return false }
        appliedTitleTopOffset = offset
        titleTopConstraint.update(offset: offset)
        return true
    }

    /// Window that owns the status bar. `UIApplication.keyWindow` is nil in
    /// scene-based apps, which is what the shared notch checks still read.
    private func interfaceSafeAreaTop() -> CGFloat {
        return interfaceWindow()?.safeAreaInsets.top ?? 0
    }

    private func interfaceWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let active = scenes.first(where: { $0.activationState == .foregroundActive })
                ?? scenes.first(where: { $0.activationState == .foregroundInactive })
            if let active = active {
                if #available(iOS 15.0, *), let window = active.keyWindow {
                    return window
                }
                let windows = active.windows
                if let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first {
                    return window
                }
            }
        }

        if let delegateWindow = UIApplication.shared.delegate?.window ?? nil {
            return delegateWindow
        }
        return UIApplication.shared.keyWindow
    }

}

public extension StatusBarNotificationBanner {
    
    func applyStyling(
        titleColor: UIColor? = nil,
        titleTextAlign: NSTextAlignment? = nil
    ) {
        
        if let titleColor = titleColor {
            titleLabel!.textColor = titleColor
        }
        
        if let titleTextAlign = titleTextAlign {
            titleLabel!.textAlignment = titleTextAlign
        }
    }
    
}
