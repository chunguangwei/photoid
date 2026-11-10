import UIKit
import Photos
import PhotosUI

/// App-owned selection gestures; PhotoKit only exposes the user's granted scope.
final class PhotoSwipePickerController: UIViewController, UICollectionViewDataSource,
  UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, PHPhotoLibraryChangeObserver {
  private let complete: ([PHAsset]?) -> Void
  private let useSystem: () -> Void
  private let zh: Bool
  private let images = PHCachingImageManager()
  private var assets = PHFetchResult<PHAsset>()
  private var selection = PhotoSweepSelection(limit: 500)
  private var finished = false, requested = false, sweeping = false
  private var point = CGPoint.zero
  private weak var sweepGesture: UIGestureRecognizer?
  private var holdGesture: UILongPressGestureRecognizer?
  private var dragGesture: UIPanGestureRecognizer?
  private var layoutWidth: CGFloat = 0
  private var link: CADisplayLink?
  private let hint = UILabel()
  private let manage = UIButton(type: .system)
  private let done = UIBarButtonItem()
  private lazy var grid: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    layout.minimumInteritemSpacing = 2; layout.minimumLineSpacing = 2
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.backgroundColor = .systemBackground; view.alwaysBounceVertical = true
    view.dataSource = self; view.delegate = self
    view.register(PhotoSwipeCell.self, forCellWithReuseIdentifier: "photo")
    return view
  }()
  init(zh: Bool, complete: @escaping ([PHAsset]?) -> Void, useSystem: @escaping () -> Void) {
    self.zh = zh; self.complete = complete; self.useSystem = useSystem
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
  private func text(_ cn: String, _ en: String) -> String { zh ? cn : en }
  override func viewDidLoad() {
    super.viewDidLoad(); view.backgroundColor = .systemBackground
    title = text("选择照片", "Select photos")
    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    done.target = self; done.action = #selector(confirm)
    navigationItem.rightBarButtonItem = done
    hint.text = text("横向滑动多选，或长按后拖动；上下滑动浏览。", "Swipe sideways or hold and drag to select. Swipe vertically to browse.")
    hint.font = .preferredFont(forTextStyle: .footnote); hint.adjustsFontForContentSizeCategory = true
    hint.numberOfLines = 0; hint.textColor = .secondaryLabel
    manage.setTitle(text("管理可见照片", "Manage visible photos"), for: .normal)
    manage.addTarget(self, action: #selector(managePhotos), for: .touchUpInside)
    manage.isHidden = true
    let system = UIButton(type: .system)
    system.setTitle(text("使用系统选图", "Use system picker"), for: .normal)
    system.addTarget(self, action: #selector(systemPicker), for: .touchUpInside)
    let controls = UIStackView(arrangedSubviews: [manage, system]); controls.distribution = .fillEqually
    let footer = UIStackView(arrangedSubviews: [hint, controls]); footer.axis = .vertical; footer.spacing = 8
    grid.translatesAutoresizingMaskIntoConstraints = false; footer.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(grid); view.addSubview(footer)
    NSLayoutConstraint.activate([
      grid.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      grid.leadingAnchor.constraint(equalTo: view.leadingAnchor), grid.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      grid.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
      footer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      footer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
    ])
    let drag = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
    drag.delegate = self; drag.maximumNumberOfTouches = 1
    dragGesture = drag
    let hold = UILongPressGestureRecognizer(target: self, action: #selector(hold(_:)))
    hold.minimumPressDuration = 0.3; hold.allowableMovement = .greatestFiniteMagnitude
    holdGesture = hold
    grid.addGestureRecognizer(hold); grid.addGestureRecognizer(drag)
    grid.panGestureRecognizer.require(toFail: drag)
    refreshCount()
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !requested else { return }; requested = true
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if status == .notDetermined {
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
        DispatchQueue.main.async { self?.authorized(status) }
      }
    } else { authorized(status) }
  }
  private func authorized(_ status: PHAuthorizationStatus) {
    guard !finished else { return }
    guard status == .authorized || status == .limited else { systemPicker(); return }
    PHPhotoLibrary.shared().register(self)
    reloadPhotos(changed: false)
  }
  private func reloadPhotos(changed: Bool) {
    stopSweep(); selection.reset()
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    manage.isHidden = status != .limited
    if status == .authorized || status == .limited {
      let options = PHFetchOptions(); options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      assets = PHAsset.fetchAssets(with: .image, options: options)
    } else { assets = PHFetchResult<PHAsset>() }
    images.stopCachingImagesForAllAssets(); grid.reloadData(); refreshCount()
    if changed { hint.text = text("相册范围已更新，请重新选择照片。", "Visible photos changed. Please select again.") }
    else if assets.count == 0 { hint.text = text("暂无可见照片。可管理可见照片，或使用系统选图。", "No visible photos. Manage access or use the system picker.") }
  }
  func photoLibraryDidChange(_ changeInstance: PHChange) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, !self.finished else { return }
      if changeInstance.changeDetails(for: self.assets) != nil || PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {
        self.reloadPhotos(changed: true)
      }
    }
  }
  @objc private func managePhotos() {
    stopSweep()
    // Completion variant is iOS 17+; the change observer reloads when the visible set changes.
    PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
  }
  private func refreshCount() {
    done.title = text("完成", "Done") + " (\(selection.selected.count)/500)"
    done.isEnabled = !selection.selected.isEmpty
    for cell in grid.visibleCells {
      guard let cell = cell as? PhotoSwipeCell, let path = grid.indexPath(for: cell) else { continue }
      cell.mark(selection.selected.contains(path.item), label: text("照片 \(path.item + 1)", "Photo \(path.item + 1)"))
    }
  }
  private func finish(_ photos: [PHAsset]?, system: Bool = false) {
    guard !finished else { return }; finished = true; stopSweep()
    images.stopCachingImagesForAllAssets()
    dismiss(animated: true) { if system { self.useSystem() } else { self.complete(photos) } }
  }
  @objc private func cancel() { finish(nil) }
  @objc private func systemPicker() { finish(nil, system: true) }
  @objc private func confirm() {
    guard !selection.selected.isEmpty else { return }
    finish(selection.selected.sorted().filter { $0 < assets.count }.map { assets.object(at: $0) })
  }
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { assets.count }
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photo", for: indexPath) as! PhotoSwipeCell
    let asset = assets.object(at: indexPath.item); cell.assetID = asset.localIdentifier
    cell.cancel = { [weak images] id in images?.cancelImageRequest(id) }
    cell.mark(selection.selected.contains(indexPath.item), label: text("照片 \(indexPath.item + 1)", "Photo \(indexPath.item + 1)"))
    let options = PHImageRequestOptions(); options.deliveryMode = .opportunistic; options.resizeMode = .fast
    // Small opportunistic thumbnails may download from iCloud; originals stay bounded reads.
    options.isNetworkAccessAllowed = true
    cell.request = images.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: options) { [weak cell] image, _ in
      DispatchQueue.main.async { if cell?.assetID == asset.localIdentifier { cell?.image.image = image } }
    }
    return cell
  }
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    collectionView.deselectItem(at: indexPath, animated: false)
    selection.toggle(indexPath.item); refreshCount()
  }
  func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) { (cell as? PhotoSwipeCell)?.cancelRequest() }
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let columns: CGFloat = collectionView.bounds.width >= 600 ? 5 : 3
    let side = floor((collectionView.bounds.width - (columns - 1) * 2) / columns)
    return CGSize(width: side, height: side)
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if grid.bounds.width != layoutWidth { layoutWidth = grid.bounds.width; grid.collectionViewLayout.invalidateLayout() }
  }
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
    // Only the sweep pair may overlap: a pan crossing its threshold must not
    // cancel an active long-press sweep (and vice versa). Everything else —
    // notably grid scrolling — keeps exclusive recognition so vertical
    // swipes browse instead of selecting.
    (gestureRecognizer === holdGesture && other === dragGesture)
      || (gestureRecognizer === dragGesture && other === holdGesture)
  }
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
    let speed = pan.velocity(in: grid)
    return abs(speed.x) > abs(speed.y) && grid.indexPathForItem(at: pan.location(in: grid)) != nil
  }
  @objc private func pan(_ gesture: UIPanGestureRecognizer) { sweep(gesture) }
  @objc private func hold(_ gesture: UILongPressGestureRecognizer) { sweep(gesture) }
  private func sweep(_ gesture: UIGestureRecognizer) {
    if gesture.state != .began && sweepGesture !== gesture { return }
    point = gesture.location(in: view)
    switch gesture.state {
    case .began:
      guard !sweeping, let index = grid.indexPathForItem(at: gesture.location(in: grid))?.item else { return }
      sweeping = true; sweepGesture = gesture; grid.isScrollEnabled = false; selection.begin(at: index); refreshCount()
      link = CADisplayLink(target: self, selector: #selector(scrollEdge(_:))); link?.add(to: .main, forMode: .common)
    case .changed: if sweeping { extendSweep() }
    case .ended, .cancelled, .failed: stopSweep()
    default: break
    }
  }
  private func extendSweep() {
    let location = grid.convert(point, from: view)
    if let index = grid.indexPathForItem(at: location)?.item { selection.move(to: index); refreshCount() }
  }
  @objc private func scrollEdge(_ tick: CADisplayLink) {
    guard sweeping else { return }
    let rect = grid.convert(grid.bounds, to: view), edge: CGFloat = 54
    let delta: CGFloat = point.y < rect.minY + edge ? -1 : (point.y > rect.maxY - edge ? 1 : 0)
    guard delta != 0 else { return }
    let minY = -grid.adjustedContentInset.top
    let maxY = max(minY, grid.contentSize.height - grid.bounds.height + grid.adjustedContentInset.bottom)
    let distance = CGFloat(tick.targetTimestamp - tick.timestamp) * 380 * delta
    grid.contentOffset.y = min(maxY, max(minY, grid.contentOffset.y + distance))
    point.y = min(rect.maxY - 3, max(rect.minY + 3, point.y)); extendSweep()
  }
  private func stopSweep() {
    link?.invalidate(); link = nil; selection.end(); sweeping = false; sweepGesture = nil; grid.isScrollEnabled = true
  }
  override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); stopSweep() }
}

private final class PhotoSwipeCell: UICollectionViewCell {
  let image = UIImageView()
  private let badge = UIImageView()
  var assetID: String?
  var request: PHImageRequestID?
  var cancel: ((PHImageRequestID) -> Void)?
  override init(frame: CGRect) {
    super.init(frame: frame); contentView.backgroundColor = .secondarySystemBackground
    image.contentMode = .scaleAspectFill; image.clipsToBounds = true; image.frame = contentView.bounds
    image.autoresizingMask = [.flexibleWidth, .flexibleHeight]; contentView.addSubview(image)
    badge.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(badge)
    NSLayoutConstraint.activate([badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6), badge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6), badge.widthAnchor.constraint(equalToConstant: 26), badge.heightAnchor.constraint(equalToConstant: 26)])
    badge.backgroundColor = .systemBackground; badge.layer.cornerRadius = 13; badge.clipsToBounds = true
    isAccessibilityElement = true
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  func mark(_ chosen: Bool, label: String) {
    badge.image = UIImage(systemName: chosen ? "checkmark.circle.fill" : "circle")
    badge.tintColor = chosen ? .systemBlue : .secondaryLabel
    contentView.layer.borderWidth = chosen ? 3 : 0; contentView.layer.borderColor = UIColor.systemBlue.cgColor
    accessibilityLabel = label; accessibilityTraits = chosen ? [.button, .selected] : [.button]
  }
  func cancelRequest() { if let request = request { cancel?(request) }; request = nil }
  override func prepareForReuse() { super.prepareForReuse(); cancelRequest(); image.image = nil; assetID = nil }
}
