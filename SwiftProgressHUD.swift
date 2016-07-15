//
//  SwiftHUD.swift
//  SwiftHUD
//
//  Created by SmithDavid on 16/7/13.
//  Copyright © 2016年 SmithDavid. All rights reserved.
//

import UIKit
import Foundation
import CoreGraphics



func SWIFT_TEXTSIZE (text:String?, font:UIFont) -> CGSize {
    
    if let str = text {
        
        let newStr = str as NSString
        if newStr.length > 0 {
            return newStr.sizeWithAttributes([NSFontAttributeName : font])
        }
    }
    
    return CGSizeZero
}

func SWIFT_MULTILINE_TEXTSIZE(text:String?, font:UIFont, maxSize:CGSize) -> CGSize {
    
    if let str = text {
        
        let newStr = str as NSString
        if newStr.length > 0 {
            return newStr.boundingRectWithSize(maxSize, options: .UsesLineFragmentOrigin, attributes: [NSFontAttributeName : font], context: nil).size
        }
    }
    
    return CGSizeZero
    
}

private let kPadding:CGFloat = 4.0

enum SwiftProgressHUDMode {
    /** 使用UIActivityIndicatorView显示进度，这是默认值 */
    /** Progress is shown using an UIActivityIndicatorView. This is the default. */
    case Indeterminate
    
    /** 使用一个圆形的，像饼状图的进度视图来显示进度 */
    /** Progress is shown using a round, pie-chart like, progress view. */
    case Determinate
    
    /** 使用一个水平进度条显示进度 */
    /** Progress is shown using a horizontal progress bar */
    case DeterminateHorizontalBar
    
    /** 使用一个圆环来显示进度 */
    /** Progress is shown using a ring-shaped progress view. */
    case AnnularDeterminate
    
    /** 使用自定义视图 */
    /** Shows a custom view */
    case CustomView
    
    /** 只显示label */
    /** Shows only labels */
    case Text
}

struct SwiftProgressHUDAnimation : OptionSetType {
    let rawValue: Int
    
    /** 改变透明度动画 */
    /** Opacity animation */
    static let Fade         = SwiftProgressHUDAnimation(rawValue: 0)
    /** 透明度+缩放的动画 */
    /** Opacity + scale animation */
    static let Zoom         = SwiftProgressHUDAnimation(rawValue: 1 << 0)
    static let ZoomOut      = SwiftProgressHUDAnimation.Zoom
    static let ZoomIn       = SwiftProgressHUDAnimation(rawValue: 1 << 2)
}

typealias SwiftProgressHUDCompletionClosure=()->Void



@objc protocol SwiftProgressHUDDelegate:NSObjectProtocol {
    
    /**
     * 在HUD在屏幕上完全隐藏时被调用
     * Called after the HUD was fully hidden from the screen.
     */
    optional func hudWasHidden(hud:SwiftProgressHUD)
    
}






class SwiftProgressHUD: UIView {
    
    /**
     * 定义一个闭包，在遮盖层完全消失的时候调用（A closure that gets called after the HUD was completely hidden.）
     */
    var completionClosure:SwiftProgressHUDCompletionClosure?
    
    
    /**
     * SwiftHUD的显示模式. 默认是 .Indeterminate.(SwiftHUD operation mode. The default is .Indeterminate.)
     *
     * @see SwiftHUDMode
     */
    var mode:SwiftProgressHUDMode = .Indeterminate {
        
        didSet {
            updateIndicators()
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /**
     * 遮盖层在显示和消失的时候使用的动画类型(The animation type that should be used when the HUD is shown and hidden. )
     *
     * @see MBProgressHUDAnimation
     */
    var animationType:SwiftProgressHUDAnimation = .Fade
    
    
    /**
     * 这个view将会在SwiftProgressHUDModeCustomView时候显示
     * The UIView (e.g., a UIImageView) to be shown when the HUD is in MBProgressHUDModeCustomView.
     * 最好使用37×37像素的图片
     * For best results use a 37 by 37 pixel view (so the bounds match the built in indicator bounds).
     */
    var customView:UIView? {
        didSet {
            updateIndicators()
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /**
     * The HUD delegate object.
     *
     * @see MBProgressHUDDelegate
     */
//    @property (MB_WEAK) id<MBProgressHUDDelegate> delegate
    weak var delegate:SwiftProgressHUDDelegate?
    
    /**
     * 活动指示器下面显示的可选的短消息。HUD自动调整大小以适应
     * An optional short message to be displayed below the activity indicator. The HUD is automatically resized to fit
     * 整个文本。如果文本太长，它会在最后显示“...”。如果没有则保持不变或设置为""，则没有显示消息。
     * the entire text. If the text is too long it will get clipped by displaying "..." at the end. If left unchanged or set to @"", then no message is displayed.
     */
    var labelText:String? {
        didSet {
            label.text = labelText
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /**
     * 一个显示在labelText下面的可选详情消息，这个消息只有在labelText属性被设置并且不是空字符串的时候显示，详情消息是多行的
     * An optional details message displayed below the labelText message. This message is displayed only if the labelText
     * property is also set and is different from an empty string (@""). The details text can span multiple lines.
     */
    var detailsLabelText:String? {
        didSet {
            detailsLabel.text = detailsLabelText
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /**
     * HUD的窗口的不透明度。默认为0.8（80%不透明度）。
     * The opacity of the HUD window. Defaults to 0.8 (80% opacity).
     */
    var opacity:Float = 0.8
    
    
    /**
     * HUD的窗口的颜色。默认为黑色。
     * The color of the HUD window. Defaults to black. If this property is set, color is set using
     * this UIColor and the opacity property is not used.  using retain because performing copy on
     * UIColor base colors (like [UIColor greenColor]) cause problems with the copyZone.
     */
    var color:UIColor = UIColor.blackColor()
    
    
    /**
     * HUD相对于父视图中心的X轴偏移。
     * The x-axis offset of the HUD relative to the centre of the superview.
     */
    var xOffset:CGFloat = 0
    
    
    /**
     * HUD相对于父视图中心的Y轴偏移。
     * The y-axis offset of the HUD relative to the centre of the superview.
     */
    var yOffset:CGFloat = 0
    
    
    /**
     * HUD本身和HUD内元素的间隙（labels, indicators or custom views），默认是20.0
     * The amount of space between the HUD edge and the HUD elements (labels, indicators or custom views).
     * Defaults to 20.0
     */
    var margin:CGFloat = 20.0
    
    
    /**
     * HUD的圆角半径，默认是10.0
     * The corner radius for the HUD
     * Defaults to 10.0
     */
    var cornerRadius:CGFloat = 10.0
    
    
    /**
     * 是否使用渐变背景的HUD。默认使用
     * Cover the HUD background view with a radial gradient.
     */
    var dimBackground:Bool = true
    
    
    /*
     * 延长HUD的显示时间(秒)，如果在任务完成前，延长时间耗尽，HUD根本就不会显示
     * Grace period is the time (in seconds) that the invoked method may be run without
     * showing the HUD. If the task finishes before the grace time runs out, the HUD will
     * not be shown at all.
     * 这可用于 HUD 显示时间很短的任务。
     * This may be used to prevent HUD display for very short tasks.
     * 默认是0.没有延长时间
     * Defaults to 0 (no grace time).
     * 必须在知道任务状态的情况下增加延长时间
     * Grace time functionality is only supported when the task status is known!
     * @see taskInProgress
     */
    var graceTime:Float = 0.0
    
    
    /**
     * HUD的最短显示时长（秒）
     * The minimum time (in seconds) that the HUD is shown.
     * 这样避免了HUD显示后立即隐藏的问题
     * This avoids the problem of the HUD being shown and than instantly hidden.
     * 默认是0.没有最短时长
     * Defaults to 0 (no minimum show time).
     */
    var minShowTime:CGFloat = 0.0
    
    
    /**
     * 显示正在执行的操作进度，需要合适的延长时间（graceTime）
     * Indicates that the executed operation is in progress. Needed for correct graceTime operation.
     * 如果你没有设置graceTime(或者是0)，它不会生效
     * If you don't set a graceTime (different than 0.0) this does nothing.
     * 当你使用“showWhileExecuting:onTarget:withObject:animated:”这个方法时，这个属性将会自动设置
     * This property is automatically set when using showWhileExecuting:onTarget:withObject:animated:.
     * 当HUD所在线程结束的时候，相当于show和hide方法立即调用
     * When threading is done outside of the HUD (i.e., when the show: and hide: methods are used directly),
     * 您需要在你的任务的开始和完成时设置此属性才能有正常的 graceTime 功能。
     * you need to set this property when your task starts and completes in order to have normal graceTime
     * functionality.
     */
    var taskInProgress:Bool = false
    
    
    /**
     * 父视图隐藏时移除HUD，默认是NO
     * Removes the HUD from its parent view when hidden.
     * Defaults to NO.
     */
    var removeFromSuperViewOnHide:Bool = false
    
    
    /**
     * main label的字体，默认字体不满足时设置这个属性
     * Font to be used for the main label. Set this property if the default is not adequate.
     */
    var labelFont:UIFont = UIFont.boldSystemFontOfSize(16){
        didSet {
            label.font = labelFont
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /**
     * main label的颜色，默认颜色不满足时设置这个属性
     * Color to be used for the main label. Set this property if the default is not adequate.
     */
    var labelColor:UIColor = UIColor.whiteColor(){
        didSet {
            label.textColor = labelColor
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /**
     * details label的字体，默认字体不满足时设置这个属性
     * Font to be used for the details label. Set this property if the default is not adequate.
     */
    var detailsLabelFont:UIFont = UIFont.boldSystemFontOfSize(12) {
        didSet {
            detailsLabel.font = detailsLabelFont
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /**
     * details label的颜色，默认颜色不满足时设置这个属性
     * Color to be used for the details label. Set this property if the default is not adequate.
     */
    var detailsLabelColor:UIColor = UIColor.whiteColor(){
        didSet {
            detailsLabel.textColor = detailsLabelColor
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /**
     * 活动指示器的颜色，默认是白色
     * The color of the activity indicator. Defaults to [UIColor whiteColor]
     * Does nothing on pre iOS 5.
     */
    var activityIndicatorColor:UIColor = UIColor.whiteColor() {
        didSet {
            updateIndicators()
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    
    /** 
     * 进度指示器的进度值，从0到1，默认是0
     * The progress of the progress indicator, from 0.0 to 1.0. Defaults to 0.0. 
     */
    var progress:NSNumber = 0.0 {
        didSet {
            indicator?.setValue(progress, forKey: "progress")
        }
    }
    
    
    /**
     * HUD挡板的最小尺寸。默认是(0, 0)
     * The minimum size of the HUD bezel. Defaults to CGSizeZero (no minimum size).
     */
    var minSize:CGSize = CGSizeZero
    
    
    
    /**
     * HUD挡板的真实尺寸
     * The actual size of the HUD bezel.
     * 您可以使用这个属性去限制 只需要处理的触摸挡板区域。
     * You can use this to limit touch handling on the bezel area only.
     * @see https://github.com/jdg/MBProgressHUD/pull/200
     */
    private (set) var size:CGSize = CGSizeZero
    
    
    /**
     * 强制HUD尺寸相等
     * Force the HUD dimensions to be equal if possible. 
     */
    var square:Bool = false
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    // MARK: - 私有变量
    private var rotationTransform:CGAffineTransform = CGAffineTransformIdentity
    
    private var indicator:UIView?
    
    private var useAnimation:Bool = false
    
    private var graceTimer:NSTimer = NSTimer()
    
    private var showStarted:NSDate?
    
    private var minShowTimer:NSTimer?
    
    private var isFinished:Bool = false
    
    private var methodForExecution:Selector?
    
    private var targetForExecution:AnyObject?
    
    private var objectForExecution:AnyObject?
    
    private lazy var label:UILabel = {
        var label = UILabel(frame:self.bounds)
        label.adjustsFontSizeToFitWidth = false
        label.textAlignment = .Center
        label.opaque = false
        label.backgroundColor = UIColor.clearColor()
        label.textColor = self.labelColor
        label.font = self.labelFont
        label.text = self.labelText
        return label
    }()
    
    private lazy var detailsLabel:UILabel = {
        
        var detailsLabel = UILabel(frame: self.bounds)
        detailsLabel.font = self.detailsLabelFont
        detailsLabel.adjustsFontSizeToFitWidth = false
        detailsLabel.textAlignment = .Center
        detailsLabel.opaque = false
        detailsLabel.backgroundColor = UIColor.clearColor()
        detailsLabel.textColor = self.detailsLabelColor
        detailsLabel.numberOfLines = 0
        detailsLabel.font = self.detailsLabelFont
        detailsLabel.text = self.detailsLabelText
        return detailsLabel
    }()
    
    //MARK: - 初始化方法（init）
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentMode = .Center
        
        autoresizingMask = [.FlexibleBottomMargin, .FlexibleTopMargin, .FlexibleLeftMargin, .FlexibleRightMargin]
        
        opaque = false
        backgroundColor = UIColor.clearColor()
        
        addSubview(label)
        registerForKVO()
        registerForNotifications()
        addSubview(detailsLabel)
        updateIndicators()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(view:UIView) {
        self.init(frame:view.bounds)
    }
    
    convenience init(window:UIWindow) {
        self.init(view:window)
    }
    
    private func creatActivityIndicator() {
        
        // Update to indeterminate indicator
        indicator?.removeFromSuperview()
        
        indicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        
        let usedIndicator = indicator as! UIActivityIndicatorView
        
        addSubview(usedIndicator)
        usedIndicator.startAnimating()
//        usedIndicator.color = activityIndicatorColor
        
    }
    
    private func updateIndicators() {
        
        let isActivityIndicator = indicator?.isKindOfClass(UIActivityIndicatorView.classForCoder())
        
        let isRoundIndicator = indicator?.isKindOfClass(SwiftRoundProgressView.classForCoder())
        
        
        if mode == .Indeterminate {
            let usedActivityIndicator = indicator as? UIActivityIndicatorView
            
            if isActivityIndicator == nil {
                creatActivityIndicator()
            }else{
                
                if (!isActivityIndicator!) {
                    creatActivityIndicator()
                }
            }
            usedActivityIndicator?.color = activityIndicatorColor
        }
        else if mode == .DeterminateHorizontalBar {
            // Update to bar determinate indicator
            indicator?.removeFromSuperview()
            indicator = SwiftBarProgressView()
            
            let usedIndicator = indicator as! SwiftBarProgressView
            
            addSubview(usedIndicator)
        }
        else if mode == .Determinate || mode == .AnnularDeterminate {
            if isRoundIndicator != nil {
                
                if !isRoundIndicator! {
                    // Update to determinante indicator
                    indicator?.removeFromSuperview()
                    indicator = SwiftRoundProgressView()
//                    let usedIndicator = indicator as! SwiftRoundProgressView
                    addSubview(indicator!)
                }
            }
            
            let usedIndicator = indicator as! SwiftRoundProgressView
            if mode == .AnnularDeterminate {
                usedIndicator.annular = true
            }
            usedIndicator.progressTintColor = activityIndicatorColor
            usedIndicator.progressTintColor = activityIndicatorColor.colorWithAlphaComponent(0.1)
        }
        else if mode == .CustomView && customView != indicator {
            // Update custom view indicator
            indicator?.removeFromSuperview()
            indicator = customView
            if let usedIndicator = indicator {
                addSubview(usedIndicator)
            }
        } else if mode == .Text {
            indicator?.removeFromSuperview()
            indicator = nil
        }
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        
        super.layoutSubviews()
    
        // Entirely cover the parent view
        let parent = superview
        if parent != nil {
            frame = parent!.bounds
        }
    
        // Determine the total width and height needed
        let maxWidth = bounds.size.width - 4 * margin
        var totalSize = CGSizeZero
        
        if indicator != nil {
            
            var indicatorF = indicator!.bounds
            indicatorF.size.width = min(indicatorF.size.width, maxWidth)
            totalSize.width = max(totalSize.width, indicatorF.size.width)
            totalSize.height += indicatorF.size.height
            
            var labelSize = SWIFT_TEXTSIZE(label.text, font: label.font)
            labelSize.width = min(labelSize.width, maxWidth)
            totalSize.width = max(totalSize.width, labelSize.width)
            totalSize.height += labelSize.height
            if labelSize.height > 0.0 && indicatorF.size.height > 0.0 {
                totalSize.height += kPadding
            }
            
            let remainingHeight = bounds.size.height - totalSize.height - kPadding - 4 * margin
            let maxSize = CGSizeMake(maxWidth, remainingHeight)
            let detailsLabelSize = SWIFT_MULTILINE_TEXTSIZE(detailsLabel.text, font: detailsLabel.font, maxSize: maxSize)
            totalSize.width = max(totalSize.width, detailsLabelSize.width)
            totalSize.height += detailsLabelSize.height
            if detailsLabelSize.height > 0.0 && (indicatorF.size.height > 0.0 || labelSize.height > 0.0) {
                totalSize.height += kPadding
            }
            
            totalSize.width += 2 * margin
            totalSize.height += 2 * margin
            
            // Position elements
            var yPos = round(((bounds.size.height - totalSize.height) / 2.0)) + margin + yOffset
            let xPos = xOffset
            indicatorF.origin.y = yPos
            indicatorF.origin.x = round((bounds.size.width - indicatorF.size.width) / 2.0) + xPos
            indicator?.frame = indicatorF
            yPos += indicatorF.size.height
            
            if labelSize.height > 0.0 && indicatorF.size.height > 0.0 {
                yPos += kPadding
            }
            var labelF:CGRect = CGRectZero
            labelF.origin.y = yPos
            labelF.origin.x = round((bounds.size.width - labelSize.width) / 2) + xPos
            labelF.size = labelSize
            label.frame = labelF
            yPos += labelF.size.height
            
            if detailsLabelSize.height > 0.0 && (indicatorF.size.height > 0.0 || labelSize.height > 0.0) {
                yPos += kPadding
            }
            var detailsLabelF = CGRectZero
            detailsLabelF.origin.y = yPos
            detailsLabelF.origin.x = round((bounds.size.width - detailsLabelSize.width) / 2) + xPos
            detailsLabelF.size = detailsLabelSize
            detailsLabel.frame = detailsLabelF
            
            // Enforce minsize and quare rules
            if square {
                let maxS = max(totalSize.width, totalSize.height)
                if (maxS <= bounds.size.width - 2 * margin) {
                    totalSize.width = maxS
                }
                if (maxS <= bounds.size.height - 2 * margin) {
                    totalSize.height = maxS
                }
            }
            if totalSize.width < minSize.width {
                totalSize.width = minSize.width
            }
            if totalSize.height < minSize.height {
                totalSize.height = minSize.height
            }
            
        }
        
        size = totalSize
    }
    
    // MARK: BG Drawing
    override func drawRect(rect: CGRect) {
        
        let currentContext = UIGraphicsGetCurrentContext()
        if let context = currentContext {
            
            UIGraphicsPushContext(context)
            
            if dimBackground {
                //Gradient colours
                let gradLocationsNum:size_t = 2
                var gradLocations:[CGFloat] = [0.0, 1.0]
                var gradColors:[CGFloat] = [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.75]
                let colorSpace:CGColorSpaceRef = CGColorSpaceCreateDeviceRGB()!
                let gradient:CGGradientRef = CGGradientCreateWithColorComponents(colorSpace, &gradColors, &gradLocations, gradLocationsNum)!
                //Gradient center
                let gradCenter = CGPointMake(self.bounds.size.width/2.0, self.bounds.size.height/2.0)
                //Gradient radius
                let gradRadius = min(self.bounds.size.width , self.bounds.size.height)
                //Gradient draw
                CGContextDrawRadialGradient(context, gradient, gradCenter, 0, gradCenter, gradRadius, CGGradientDrawingOptions.DrawsAfterEndLocation)
            }
            
            // Set background rect color
            CGContextSetFillColorWithColor(context, color.CGColor)
            
            // Center HUD
            let allRect = bounds
            // Draw rounded HUD backgroud rect
            let boxRect = CGRectMake(round((allRect.size.width - size.width) / 2) + self.xOffset, round((allRect.size.height - size.height) / 2) + self.yOffset, size.width, size.height)
            let radius = cornerRadius
            CGContextBeginPath(context)
            CGContextMoveToPoint(context, CGRectGetMinX(boxRect) + radius, CGRectGetMinY(boxRect))
            CGContextAddArc(context, CGRectGetMaxX(boxRect) - radius, CGRectGetMinY(boxRect) + radius, radius, 3.0 * CGFloat(M_PI) / 2, 0, 0)
            CGContextAddArc(context, CGRectGetMaxX(boxRect) - radius, CGRectGetMaxY(boxRect) - radius, radius, 0, CGFloat(M_PI) / 2.0, 0)
            CGContextAddArc(context, CGRectGetMinX(boxRect) + radius, CGRectGetMaxY(boxRect) - radius, radius, CGFloat(M_PI) / 2.0, CGFloat(M_PI), 0)
            CGContextAddArc(context, CGRectGetMinX(boxRect) + radius, CGRectGetMinY(boxRect) + radius, radius, CGFloat(M_PI), 3 * CGFloat(M_PI) / 2.0, 0)
            CGContextClosePath(context)
            CGContextFillPath(context)
            
            UIGraphicsPopContext()
        }
        
    }
    
    // MARK: - KVO
    private func registerForKVO() -> Void {
        
        let keyPathArray = observableKeypaths()
        
        
        for keyPath in keyPathArray {
            let key = keyPath as! String
            print(key)
            addObserver(self, forKeyPath: key, options: .New, context: nil)
        }
    }
    
    private func unregisterFromKVO() {
        for keyPath in observableKeypaths() {
            removeObserver(self, forKeyPath: keyPath as! String)
        }
    }
    
    private func observableKeypaths() -> NSArray {
        return ["mode", "customView", "labelText", "labelFont", "labelColor", "detailsLabelText", "detailsLabelFont", "detailsLabelColor", "progress", "activityIndicatorColor"]
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        print(keyPath)
        if let key = keyPath {
            
            if (!NSThread.isMainThread()) {
                performSelectorOnMainThread(#selector(SwiftProgressHUD.updateUIForKeypath(_:)), withObject:key, waitUntilDone: false)
            } else {
                updateUIForKeypath(key)
            }
        }
    }
    
    func updateUIForKeypath(key:String) {
        
        let keyPath = key as NSString
        
        if (keyPath.isEqualToString("mode") || keyPath.isEqualToString("customView") ||
        keyPath.isEqualToString("activityIndicatorColor")) {
            updateIndicators()
        } else if (keyPath.isEqualToString("labelText")) {
            label.text = labelText
        } else if (keyPath.isEqualToString("labelFont")) {
            label.font = labelFont
        } else if (keyPath.isEqualToString("labelColor")) {
            label.textColor = labelColor
        } else if (keyPath.isEqualToString("detailsLabelText")) {
            detailsLabel.text = detailsLabelText
        } else if (keyPath.isEqualToString("detailsLabelFont")) {
            detailsLabel.font = detailsLabelFont
        } else if (keyPath.isEqualToString("detailsLabelColor")) {
            detailsLabel.textColor = detailsLabelColor
        } else if (keyPath.isEqualToString("progress")) {
            
            indicator?.setValue(NSNumber(float: progress as Float), forKey: "progress")
            return
        }
        setNeedsLayout()
        setNeedsDisplay()
    }
    
    // MARK: - Notifications
    private func registerForNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SwiftProgressHUD.statusBarOrientationDidChange(_:)), name: UIApplicationDidChangeStatusBarOrientationNotification, object: nil)
        
    }
    
    
    private func unregisterFromNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidChangeStatusBarOrientationNotification, object: nil)
    }
    
    func statusBarOrientationDidChange(notification: NSNotification) {
        
        if (superview == nil) {
            return
        } else {
            updateForCurrentOrientationAnimated(true)
        }

    }
    
    private func updateForCurrentOrientationAnimated(animated:Bool) {
        // Stay in sync with the superview in any case
        if (superview != nil) {
            bounds = superview!.bounds
            setNeedsDisplay()
        }
    }
    
    
    // MARK: - Class methods
    class func showHUDAddedToView(view:UIView, animated:Bool) -> SwiftProgressHUD {
        let hud = SwiftProgressHUD(view: view)
        hud.removeFromSuperViewOnHide = true
        view.addSubview(hud)
        hud.show(animated)
        return hud;
    }
    
    class func hideHUDForView(view:UIView, animated:Bool) -> Bool {
        
        let hud = HUDForView(view)
        
        if let newHUD = hud {
            
            newHUD.removeFromSuperViewOnHide = true
            newHUD.hide(animated)
            return true
        }
            return false;
    }
    
    class func hideAllHUDsForView(view:UIView, animated:Bool) -> Int {
        
        let huds = allHUDsForView(view)
        
        for hud in huds as! [SwiftProgressHUD] {
            hud.removeFromSuperViewOnHide = true
            hud.hide(animated)
        }
        return huds.count
        
    }
    
    class func HUDForView(view:UIView) -> SwiftProgressHUD? {
        
        let subviewsEnum = view.subviews.reverse()
        
        for subview in subviewsEnum {
            
            if subview.isKindOfClass(self) {
                return subview as? SwiftProgressHUD
            }
        }
        return nil
    }
    
    class func allHUDsForView(view:UIView) -> NSArray {
        
        let huds = NSMutableArray()
        let subviewArray = view.subviews
        
        for aView in subviewArray {
            
            if aView.isKindOfClass(self) {
                huds.addObject(aView)
            }
            
        }
        return NSArray(array: huds)
    }
    
    
    // MARK: - Show & Hide
    func show(animated:Bool) -> Void {
        assert(NSThread.isMainThread(), "MBProgressHUD needs to be accessed on the main thread.")
        
        useAnimation = animated
        
        // If the grace time is set postpone the HUD display
        if graceTime > 0.0 {
            let newGraceTimer = NSTimer(timeInterval: NSTimeInterval(graceTime), target: self, selector: #selector(SwiftProgressHUD.handleGraceTimer(_:)), userInfo: nil, repeats: false)
            NSRunLoop.currentRunLoop().addTimer(newGraceTimer, forMode: NSRunLoopCommonModes)
            graceTimer = newGraceTimer;
        } else {    // ... otherwise show the HUD imediately
            showUsingAnimation(useAnimation)
        }
    }
    
    
    func hide(animated:Bool) -> Void {
        assert(NSThread.isMainThread(), "MBProgressHUD needs to be accessed on the main thread.")
        useAnimation = animated;
        // If the minShow time is set, calculate how long the hud was shown,
        // and pospone the hiding operation if necessary
        if (minShowTime > 0.0 && showStarted != nil) {
            let interv = NSDate().timeIntervalSinceDate(showStarted!)
            
            if CGFloat(interv) < self.minShowTime {
                self.minShowTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(minShowTime - CGFloat(interv)), target:self, selector: #selector(SwiftProgressHUD.handleMinShowTimer(_:)), userInfo: nil, repeats: false)
                return
            }
        }
        // ... otherwise hide the HUD immediately
//        [self hideUsingAnimation:useAnimation];
        hideUsingAnimation(useAnimation)
    }
    
    
    func hide(animated:Bool, afterDelay delay:NSTimeInterval) -> Void {
        performSelector(#selector(SwiftProgressHUD.hideDelayed(_:)), withObject: NSNumber(bool: animated), afterDelay: delay)
    }
    
    func hideDelayed(animated:NSNumber) -> Void {
        hide(animated.boolValue)
    }
    
    // MARK: - Timer callbacks
    func handleGraceTimer(theTimer:NSTimer) -> Void {
        // Show the HUD only if the task is still running
        if (taskInProgress) {
            showUsingAnimation(useAnimation)
        }
    }
    
    func handleMinShowTimer(theTimer:NSTimer) -> Void {
        hideUsingAnimation(useAnimation)
    }
    
    // MARK: - View Hierrarchy
    override func didMoveToSuperview() {
        updateForCurrentOrientationAnimated(false)
    }
    
    // MARK: - Internal show & hide operations
    private func showUsingAnimation(animated:Bool) -> Void {
        // Cancel any scheduled hideDelayed: calls
        NSObject.cancelPreviousPerformRequestsWithTarget(self)
        setNeedsDisplay()
        
        if animated && animationType == .ZoomIn {
        self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(0.5, 0.5));
        } else if animated && animationType == .ZoomOut {
        self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(1.5, 1.5));
        }
        self.showStarted = NSDate()
        // Fade in
        if (animated) {
            UIView.animateWithDuration(0.30, animations: {
                self.alpha = 1.0
                if (self.animationType == .ZoomIn || self.animationType == .ZoomOut) {
                    self.transform = self.rotationTransform
                }
            })
        }
        else {
            self.alpha = 1.0
        }
    }
    
    
    private func hideUsingAnimation(animated:Bool) -> Void {
        
        // Fade out
        if animated && showStarted != nil {
            UIView.animateWithDuration(0.3, animations: { 
                
                    // 0.02 prevents the hud from passing through touches during the animation the hud will get completely hidden
                    // in the done method
                    if (self.animationType == .ZoomIn) {
                        self.transform = CGAffineTransformConcat(self.rotationTransform, CGAffineTransformMakeScale(1.5, 1.5));
                    } else if (self.animationType == .ZoomOut) {
                        self.transform = CGAffineTransformConcat(self.rotationTransform, CGAffineTransformMakeScale(0.5, 0.5));
                    }
                    self.alpha = 0.02
                }, completion: { (_) in
                    self.done()
            })
        }else{
            self.alpha = 0.0;
            done()
        }
        self.showStarted = nil;
    }
    
    private func done() -> Void {
        NSObject.cancelPreviousPerformRequestsWithTarget(self)
        isFinished = true
        self.alpha = 0.0
        if (removeFromSuperViewOnHide) {
            removeFromSuperview()
        }
        
        if (completionClosure != nil) {
            completionClosure!()
            self.completionClosure = nil
        }
        
        delegate?.hudWasHidden!(self)
    }
    
    deinit {
        unregisterFromKVO()
        unregisterFromNotifications()
    }
    
}

/**
 * 通过填满一圈显示明确进度进展视图 （饼图）
 * A progress view for showing definite progress by filling up a circle (pie chart).
 */
class SwiftRoundProgressView: UIView {
    /**
     * 进度（0到1）
     * Progress (0.0 to 1.0)
     */
    var progress:CGFloat = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    
    /**
     * 指示器进度颜色。默认白色
     * Indicator progress color.
     * Defaults to white [UIColor whiteColor]
     */
    var progressTintColor:UIColor = UIColor.whiteColor() {
        didSet {
            setNeedsDisplay()
        }
    }
    
    
    /**
     * 指示器背景颜色，默认为半透明的白色（阿尔法0.1）
     * Indicator background (non-progress) color.
     * Defaults to translucent white (alpha 0.1)
     */
    var backgroundTintColor = UIColor(white: 1.0, alpha: 0.1) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    
    /*
     * 显示模式（NO:圆形，YES:环形）默认是圆形
     * Display mode - false = round or true = annular. Defaults to round.
     */
    var annular:Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    
    // MARK: - Lifecycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor.clearColor()
        opaque = false
        progress = 0
        annular = false
        
        registerForKVO()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - KVO
    private func registerForKVO() {
        for keyPath in observableKeypaths() {
            addObserver(self, forKeyPath: keyPath as! String, options: .New, context: nil)
        }
    }
    
    private func unregisterFromKVO() {
        for keyPath in observableKeypaths() {
            removeObserver(self, forKeyPath: keyPath as! String)
        }
    }
    
    private func observableKeypaths() -> NSArray {
        return ["progressTintColor", "backgroundTintColor", "progress", "annular"]
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        setNeedsDisplay()
    }
    
    deinit {
        unregisterFromKVO()
    }
    
    // MARK: - Drawing
    override func drawRect(rect: CGRect) {
        
        let allRect = bounds
        let circleRect = CGRectInset(allRect, 2.0, 2.0)
        let currentContext:CGContextRef? = UIGraphicsGetCurrentContext()
        
        if let context = currentContext {
            
            if (annular) {
                // Draw background
                let lineWidth:CGFloat = 2.0
                
                let processBackgroundPath = UIBezierPath()
                processBackgroundPath.lineWidth = lineWidth
                processBackgroundPath.lineCapStyle = CGLineCap.Butt
                let center = CGPoint(x: self.bounds.size.width/2.0, y: self.bounds.size.height/2.0)
                
                let radius = (self.bounds.size.width - lineWidth)/2.0
                let startAngle = -(CGFloat(M_PI) / 2) // 90 degrees
                var endAngle = (2 * CGFloat(M_PI)) + startAngle
                processBackgroundPath.addArcWithCenter(center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                backgroundTintColor.set()
                processBackgroundPath.stroke()
                // Draw progress
                let processPath = UIBezierPath()
                processPath.lineCapStyle = .Square
                processPath.lineWidth = lineWidth
                endAngle = (self.progress * 2.0 * CGFloat(M_PI)) + startAngle
                processPath.addArcWithCenter(center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                progressTintColor.set()
                processPath.stroke()
            } else {
                // Draw background
                progressTintColor.setStroke()
                backgroundTintColor.setFill()
                CGContextSetLineWidth(context, 2.0)
                CGContextFillEllipseInRect(context, circleRect)
                CGContextStrokeEllipseInRect(context, circleRect)
                // Draw progress
                let center = CGPoint(x: allRect.size.width / 2.0, y: allRect.size.height / 2.0)
                let radius = (allRect.size.width - 4.0) / 2.0
                let startAngle = -(CGFloat(M_PI) / 2.0) // 90 degrees
                let endAngle = (self.progress * 2.0 * CGFloat(M_PI)) + startAngle
                progressTintColor.setFill()
                CGContextMoveToPoint(context, center.x, center.y)
                CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0)
                CGContextClosePath(context)
                CGContextFillPath(context)
            }

        }
    }
    
}

/**
 * 条形进度视图
 * A flat bar progress view.
 */
class SwiftBarProgressView: UIView {
    
    /**
     * 进度（0到1）
     * Progress (0.0 to 1.0)
     */
    var progress:CGFloat = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /**
     * 条形图边框线颜色。
     * Bar border line color.
     * Defaults to white [UIColor whiteColor].
     */
    var lineColor = UIColor.whiteColor() {
        didSet {
            setNeedsDisplay()
        }
    }
    
    
    /**
     * 条形图背景颜色。
     * Bar background color.
     * Defaults to clear [UIColor clearColor]
     */
    var progressRemainingColor:UIColor = UIColor.clearColor() {
        didSet {
            setNeedsDisplay()
        }
    }
    
    
    /** 
     * 条形图进度条颜色
     * Bar progress color.
     * Defaults to white [UIColor whiteColor].
     */
    var progressColor:UIColor = UIColor.whiteColor()
    
    
    // MARK: - Lifecycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor.clearColor()
        opaque = false
        registerForKVO()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - KVO
    private func registerForKVO() {
        for keyPath in observableKeypaths() {
            addObserver(self, forKeyPath: keyPath as! String, options: .New, context: nil)
        }
    }
    
    private func unregisterFromKVO() {
        for keyPath in observableKeypaths() {
            removeObserver(self, forKeyPath: keyPath as! String)
        }
    }
    
    private func observableKeypaths() -> NSArray {
        return ["lineColor", "progressRemainingColor", "progressColor", "progress"]
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        setNeedsDisplay()
    }
    
    deinit {
        unregisterFromKVO()
    }
    
    // MARK: Drawing
    override func drawRect(rect: CGRect) {
        
        let currentContext = UIGraphicsGetCurrentContext()
        
        if let context = currentContext {
            
            CGContextSetLineWidth(context, 2)
            CGContextSetStrokeColorWithColor(context,lineColor.CGColor)
            CGContextSetFillColorWithColor(context, progressRemainingColor.CGColor)
            
            // Draw background
            var radius = (rect.size.height / 2.0) - 2.0
            CGContextMoveToPoint(context, 2.0, rect.size.height/2.0)
            CGContextAddArcToPoint(context, 2.0, 2.0, radius + 2.0, 2.0, radius)
            CGContextAddLineToPoint(context, rect.size.width - radius - 2.0, 2.0)
            CGContextAddArcToPoint(context, rect.size.width - 2.0, 2.0, rect.size.width - 2.0, rect.size.height / 2.0, radius)
            CGContextAddArcToPoint(context, rect.size.width - 2.0, rect.size.height - 2.0, rect.size.width - radius - 2.0, rect.size.height - 2.0, radius)
            CGContextAddLineToPoint(context, radius + 2.0, rect.size.height - 2.0)
            CGContextAddArcToPoint(context, 2.0, rect.size.height - 2.0, 2.0, rect.size.height/2.0, radius)
            CGContextFillPath(context)
            
            // Draw border
            CGContextMoveToPoint(context, 2.0, rect.size.height/2.0)
            CGContextAddArcToPoint(context, 2.0, 2.0, radius + 2.0, 2.0, radius)
            CGContextAddLineToPoint(context, rect.size.width - radius - 2.0, 2.0)
            CGContextAddArcToPoint(context, rect.size.width - 2.0, 2.0, rect.size.width - 2.0, rect.size.height / 2.0, radius)
            CGContextAddArcToPoint(context, rect.size.width - 2.0, rect.size.height - 2.0, rect.size.width - radius - 2.0, rect.size.height - 2.0, radius)
            CGContextAddLineToPoint(context, radius + 2.0, rect.size.height - 2.0)
            CGContextAddArcToPoint(context, 2.0, rect.size.height - 2.0, 2.0, rect.size.height/2.0, radius)
            CGContextStrokePath(context)
            
            CGContextSetFillColorWithColor(context, progressColor.CGColor)
            radius = radius - 2.0
            let amount = self.progress * rect.size.width
            
            // Progress in the middle area
            if amount >= radius + 4.0 && amount <= (rect.size.width - radius - 4.0) {
                CGContextMoveToPoint(context, 4.0, rect.size.height/2.0)
                CGContextAddArcToPoint(context, 4.0, 4.0, radius + 4.0, 4.0, radius)
                CGContextAddLineToPoint(context, amount, 4.0)
                CGContextAddLineToPoint(context, amount, radius + 4.0)
                
                CGContextMoveToPoint(context, 4.0, rect.size.height/2.0)
                CGContextAddArcToPoint(context, 4.0, rect.size.height - 4.0, radius + 4.0, rect.size.height - 4.0, radius)
                CGContextAddLineToPoint(context, amount, rect.size.height - 4.0)
                CGContextAddLineToPoint(context, amount, radius + 4.0)
                
                CGContextFillPath(context)
            }
                
                // Progress in the right arc
            else if amount > radius + 4.0 {
                let x = amount - (rect.size.width - radius - 4.0)
                
                CGContextMoveToPoint(context, 4.0, rect.size.height/2.0)
                CGContextAddArcToPoint(context, 4.0, 4.0, radius + 4.0, 4.0, radius)
                CGContextAddLineToPoint(context, rect.size.width - radius - 4.0, 4.0)
                var angle = -acos(x/radius)
                if (isnan(angle)) {
                    angle = 0
                }
                CGContextAddArc(context, rect.size.width - radius - 4.0, rect.size.height/2.0, radius, CGFloat(M_PI), angle, 0)
                CGContextAddLineToPoint(context, amount, rect.size.height/2.0)
                
                CGContextMoveToPoint(context, 4.0, rect.size.height/2.0)
                CGContextAddArcToPoint(context, 4.0, rect.size.height - 4.0, radius + 4.0, rect.size.height - 4.0, radius)
                CGContextAddLineToPoint(context, rect.size.width - radius - 4.0, rect.size.height - 4.0)
                angle = acos(x/radius)
                if (isnan(angle)) {
                    angle = 0
                }
                CGContextAddArc(context, rect.size.width - radius - 4.0, rect.size.height/2.0, radius, -CGFloat(M_PI), angle, 1)
                CGContextAddLineToPoint(context, amount, rect.size.height/2.0)
                
                CGContextFillPath(context)
            }
                
                // Progress is in the left arc
            else if amount < radius + 4.0 && amount > 0 {
                CGContextMoveToPoint(context, 4.0, rect.size.height/2.0)
                CGContextAddArcToPoint(context, 4.0, 4.0, radius + 4.0, 4.0, radius)
                CGContextAddLineToPoint(context, radius + 4.0, rect.size.height/2.0)
                
                CGContextMoveToPoint(context, 4.0, rect.size.height/2.0)
                CGContextAddArcToPoint(context, 4.0, rect.size.height - 4.0, radius + 4.0, rect.size.height - 4.0, radius)
                CGContextAddLineToPoint(context, radius + 4.0, rect.size.height/2.0)
                
                CGContextFillPath(context)
            }
            
        }
    
    }
    
}
