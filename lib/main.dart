import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Test',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final CollectionReference _products = FirebaseFirestore.instance.collection('products');

  String _searchQuery = '';
  double? _minPrice;
  double? _maxPrice;

  String _filterFeedback = '';

  // Create or update product
  Future<void> _createOrUpdate([DocumentSnapshot? documentSnapshot]) async {
    String action = 'create';
    if (documentSnapshot != null) {
      action = 'update';
      _nameController.text = documentSnapshot['name'];
      _priceController.text = documentSnapshot['price'].toString();
    }

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: Text(action == 'create' ? 'Create' : 'Update'),
                onPressed: () async {
                  String name = _nameController.text;
                  double price = double.parse(_priceController.text);
                  if (name.isNotEmpty && price != null) {
                    if (action == 'create') {
                      await _products.add({"name": name, "price": price});
                    }
                    if (action == 'update') {
                      await _products.doc(documentSnapshot!.id).update({
                        "name": name,
                        "price": price,
                      });
                    }
                    _nameController.text = '';
                    _priceController.text = '';
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Deleting a product by id
  Future<void> _deleteProduct(String productId) async {
    await _products.doc(productId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have successfully deleted a product')),
    );
  }

  // Filter products by price range
  void _filterProducts() {
    setState(() {
      _minPrice = _minPriceController.text.isNotEmpty
          ? double.tryParse(_minPriceController.text)
          : null;
      _maxPrice = _maxPriceController.text.isNotEmpty
          ? double.tryParse(_maxPriceController.text)
          : null;
      _filterFeedback = 'Filters applied: Min Price: ${_minPrice ?? 'Any'} - Max Price: ${_maxPrice ?? 'Any'}';
    });
  }

  // Reset filters
  void _resetFilter() {
    setState(() {
      _minPriceController.clear();
      _maxPriceController.clear();
      _minPrice = null;
      _maxPrice = null;
      _filterFeedback = 'Filters reset';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ICA 12'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: ProductSearchDelegate(_products),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar at the top
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query.toLowerCase();
                });
              },
            ),
          ),
          // Filter section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Min Price',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Max Price',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _filterProducts,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetFilter,
                ),
              ],
            ),
          ),
          // Display filter feedback
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              _filterFeedback,
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blue),
            ),
          ),
          // StreamBuilder to display filtered products
          Expanded(
            child: StreamBuilder(
              stream: _products.snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> streamSnapshot) {
                if (streamSnapshot.hasData) {
                  final filteredProducts = streamSnapshot.data!.docs.where((documentSnapshot) {
                    final name = documentSnapshot['name'].toString().toLowerCase();
                    final price = documentSnapshot['price'];

                    // Check if the product matches search query and price range
                    final matchesSearch = name.contains(_searchQuery);
                    final matchesPriceRange =
                        (_minPrice == null || price >= _minPrice!) &&
                            (_maxPrice == null || price <= _maxPrice!);

                    return matchesSearch && matchesPriceRange;
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return const Center(
                      child: Text('No products found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final documentSnapshot = filteredProducts[index];
                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          title: Text(documentSnapshot['name']),
                          subtitle: Text(documentSnapshot['price'].toString()),
                          trailing: SizedBox(
                            width: 100,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _createOrUpdate(documentSnapshot),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteProduct(documentSnapshot.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createOrUpdate(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Search delegate for filtering the product list based on search query
class ProductSearchDelegate extends SearchDelegate {
  final CollectionReference productsCollection;

  ProductSearchDelegate(this.productsCollection);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: productsCollection.get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredProducts = snapshot.data!.docs.where((documentSnapshot) {
          final name = documentSnapshot['name'].toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();

        if (filteredProducts.isEmpty) {
          return const Center(
            child: Text('No products found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          );
        }

        return ListView.builder(
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final documentSnapshot = filteredProducts[index];
            return ListTile(
              title: Text(documentSnapshot['name']),
              subtitle: Text(documentSnapshot['price'].toString()),
              onTap: () {
                // You can perform actions when an item is tapped, e.g., navigate to product details
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}
