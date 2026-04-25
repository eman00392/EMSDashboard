import UIKit

// MARK: - Tag Flow View
// A view that lays out pill subviews left-to-right, wrapping to
// new lines automatically — like CSS flexbox with flex-wrap.

class TagFlowView: UIView {

    var spacing: CGFloat = 6
    private var pillViews: [UIView] = []

    func setPills(_ views: [UIView]) {
        pillViews.forEach { $0.removeFromSuperview() }
        pillViews = views
        pillViews.forEach { addSubview($0) }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layout(fitting: bounds.width)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: layout(fitting: bounds.width == 0 ? 320 : bounds.width))
    }

    @discardableResult
    private func layout(fitting maxWidth: CGFloat) -> CGFloat {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight:  CGFloat = 0

        for pill in pillViews {
            let size = pill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)

            if x + size.width > maxWidth, x > 0 {
                // Wrap to next row
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            pill.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return pillViews.isEmpty ? 0 : y + rowHeight
    }
}

// MARK: - Address Notes View
// Drop-in UIView showing address notes as wrapping tag pills + detail text.
// Hides itself automatically when there are no notes.

class AddressNotesView: UIView {

    // MARK: - UI
    private let headerLabel  = UILabel()
    private let tagFlowView  = TagFlowView()           // wrapping flow — no clipping
    private let detailLabel  = UILabel()
    private let divider      = UIView()

    // Keep a height constraint on tagFlowView so the parent stack knows its size
    private var tagFlowHeightConstraint: NSLayoutConstraint!

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        headerLabel.text      = "📍 ADDRESS NOTES"
        headerLabel.font      = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        headerLabel.textColor = UIColor(white: 0.45, alpha: 1)

        tagFlowView.translatesAutoresizingMaskIntoConstraints = false
        tagFlowHeightConstraint = tagFlowView.heightAnchor.constraint(equalToConstant: 0)
        tagFlowHeightConstraint.isActive = true

        detailLabel.font          = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor     = UIColor(white: 0.7, alpha: 1)
        detailLabel.numberOfLines = 0
        detailLabel.isHidden      = true

        divider.backgroundColor = UIColor(white: 0.2, alpha: 1)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let stack = UIStackView(arrangedSubviews: [divider, headerLabel, tagFlowView, detailLabel])
        stack.axis      = .vertical
        stack.spacing   = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        isHidden = true
    }

    // MARK: - Layout
    // Called after bounds are known so tagFlowView height can be calculated

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTagFlowHeight()
    }

    private func updateTagFlowHeight() {
        guard !isHidden, bounds.width > 0 else { return }
        let h = tagFlowView.intrinsicContentSize.height
        if tagFlowHeightConstraint.constant != h {
            tagFlowHeightConstraint.constant = h
            tagFlowView.setNeedsLayout()
        }
    }

    // MARK: - Configure

    func configure(with notes: [AddressNote]) {
        guard !notes.isEmpty else {
            isHidden = true
            tagFlowView.setPills([])
            tagFlowHeightConstraint.constant = 0
            detailLabel.isHidden = true
            detailLabel.text     = nil
            return
        }

        // Collect tags + details from all matching notes
        var allTags:    [String] = []
        var allDetails: [String] = []

        for note in notes {
            allTags.append(contentsOf: note.tags)
            if !note.details.isEmpty { allDetails.append(note.details) }
        }

        // Deduplicate preserving order
        let uniqueTags = Array(NSOrderedSet(array: allTags)) as? [String] ?? allTags

        // Build pill views
        let pills = uniqueTags.map { makePill(for: $0) }
        tagFlowView.setPills(pills)
        tagFlowHeightConstraint.constant = pills.isEmpty ? 0 : 28 // initial estimate; updated in layoutSubviews

        // Details
        if !allDetails.isEmpty {
            detailLabel.text     = allDetails.joined(separator: "\n")
            detailLabel.isHidden = false
        } else {
            detailLabel.isHidden = true
            detailLabel.text     = nil
        }

        isHidden = uniqueTags.isEmpty && allDetails.isEmpty
        setNeedsLayout()
    }

    // MARK: - Make Pill

    private func makePill(for key: String) -> UIView {
        let info = AddressNotesManager.shared.tagInfo(for: key)

        let pill = UIView()
        pill.layer.cornerRadius = 8
        pill.translatesAutoresizingMaskIntoConstraints = false

        let label       = UILabel()
        label.font      = .systemFont(ofSize: 12, weight: .semibold)
        label.numberOfLines = 1

        if let info = info {
            label.text           = "\(info.emoji) \(info.label)"
            label.textColor      = pillColor(info.color)
            pill.backgroundColor = pillColor(info.color).withAlphaComponent(0.18)
            pill.layer.borderWidth = 1
            pill.layer.borderColor = pillColor(info.color).withAlphaComponent(0.5).cgColor
        } else {
            label.text           = key
            label.textColor      = UIColor(white: 0.7, alpha: 1)
            pill.backgroundColor = UIColor(white: 0.18, alpha: 1)
        }

        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10)
        ])

        return pill
    }

    // MARK: - Colour Lookup

    private func pillColor(_ color: TagColor) -> UIColor {
        switch color {
        case .red:    return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .blue:   return .systemBlue
        case .purple: return .systemPurple
        case .gray:   return .systemGray
        }
    }
}
