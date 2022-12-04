//
//  ViewController.swift
//  tableview-binding
//
//  Created by Kelvin Fok on 30/11/22.
//

import UIKit
import Combine

class ViewModel {
  
  enum Input {
    case viewDidLoad
    case onProductCellEvent(event: ProductCellEvent, product: Product)
    case onResetButtonTap
  }
  
  enum Output {
    case setProducts(products: [Product])
    case updateView(numberOfItemsInCart: Int, totalCost: Int, likedProductIds: Set<Int>, productQuantities: [Int: Int])
  }
  
  private let output = PassthroughSubject<ViewModel.Output, Never>()
  private var cancellables = Set<AnyCancellable>()
  
  @Published private var cart: [Product: Int] = [:]
  @Published private var likes: [Product: Bool] = [:]
  
  init() {
    observe()
  }
  
  func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never> {
    input.sink { [unowned self] event in
      switch event {
      case .viewDidLoad:
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [unowned self] in
          output.send(.setProducts(products: Product.collection))
          output.send(.updateView(numberOfItemsInCart: numberOfItemsInCart, totalCost: totalCost, likedProductIds: likedProductIds, productQuantities: productQuantities))
        }
      case .onResetButtonTap:
        cart.removeAll()
        likes.removeAll()
        output.send(.updateView(numberOfItemsInCart: numberOfItemsInCart, totalCost: totalCost, likedProductIds: likedProductIds, productQuantities: productQuantities))
      case .onProductCellEvent(let event, let product):
        switch event {
        case .quantityDidChange(let value):
          cart[product] = value
          output.send(.updateView(numberOfItemsInCart: numberOfItemsInCart, totalCost: totalCost, likedProductIds: likedProductIds, productQuantities: productQuantities))
        case .heartDidTap:
          if let value = likes[product] {
            likes[product] = !value
          } else {
            likes[product] = true
          }
          output.send(.updateView(numberOfItemsInCart: numberOfItemsInCart, totalCost: totalCost, likedProductIds: likedProductIds, productQuantities: productQuantities))
        }
      }
    }.store(in: &cancellables)
    return output.eraseToAnyPublisher()
  }
  
  private func observe() {
    $cart.dropFirst().sink { dict in
      dict.forEach { k,v in
        print("\(k.name) - \(v)")
      }
      print("=======")
    }.store(in: &cancellables)
    
    $likes.dropFirst().sink { dict in
      let products = dict.filter({ $0.value == true }).map({ $0.key.name })
      print("❤️ \(products)")
    }.store(in: &cancellables)
  }
  
  private var numberOfItemsInCart: Int {
    cart.reduce(0, { $0 + $1.value })
  }
  
  private var totalCost: Int {
    cart.reduce(0, { $0 + ($1.value * $1.key.price )})
  }
  
  private var likedProductIds: Set<Int> {
    let array = likes.filter { $0.value == true }.map { $0.key.id }
    return Set(array)
  }
  
  private var productQuantities: [Int: Int] {
    var temp = [Int: Int]()
    cart.forEach { key, value in
      temp[key.id] = value
    }
    return temp
  }
}

class TableViewController: UITableViewController {
  
  private var numberOfItemsInCart: Int = 0
  private var totalCost: Int = 0
  private var likedProductIds: Set<Int> = []
  private var productQuantities: [Int: Int] = [:]
  private var products: [Product] = []
  
  private let vm = ViewModel()
  
  private let output = PassthroughSubject<ViewModel.Input, Never>()
  private var cancellables = Set<AnyCancellable>()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    observe()
    output.send(.viewDidLoad)
  }
  
  private func observe() {

    vm.transform(input: output.eraseToAnyPublisher()).sink { [unowned self] event in
      switch event {
      case .setProducts(let products):
        self.products = products
      case let .updateView(numberOfItemsInCart, totalCost, likedProductIds, productQuantities):
        self.numberOfItemsInCart = numberOfItemsInCart
        self.totalCost = totalCost
        self.likedProductIds = likedProductIds
        self.productQuantities = productQuantities
        self.tableView.reloadData()
      }
    }.store(in: &cancellables)
  }
  
  @IBAction func resetButtonTapped(_ sender: Any) {
    output.send(.onResetButtonTap)
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return products.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cellId") as! ProductTableViewCell
    let product = products[indexPath.item]
    cell.setProduct(
      product: product,
      quantity: productQuantities[product.id] ?? 0,
      isLiked: likedProductIds.contains(product.id))
    cell.eventPublisher.sink { [weak self] event in
      self?.output.send(.onProductCellEvent(event: event, product: product))
    }.store(in: &cell.cancellables)
    return cell
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 88
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return String(format: "Number of items: %d", numberOfItemsInCart)
  }
  
  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    return String(format: "Total cost: $%d", totalCost)
  }
}
