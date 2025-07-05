import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShopPerformanceScreen extends StatefulWidget {
  const ShopPerformanceScreen({super.key});

  @override
  State<ShopPerformanceScreen> createState() => _ShopPerformanceScreenState();
}

class PerformanceData {
  final double totalSales;
  final int orderCount;
  final double salesPerOrder;
  final int buyerCount;
  final double salesPerBuyer;
  final double conversionRate;
  final List<FlSpot> salesChartData;
  final List<FlSpot> ordersChartData;
  final List<FlSpot> salesPerOrderChartData;
  final List<FlSpot> buyersChartData;
  final List<FlSpot> salesPerBuyerChartData;
  final List<FlSpot> conversionRateChartData;
  final double salesPercentageChange;
  final double ordersPercentageChange;
  final double salesPerOrderPercentageChange;
  final double buyersPercentageChange;
  final double salesPerBuyerPercentageChange;
  final double conversionRatePercentageChange;
  final double shopRating;

  PerformanceData({
    this.totalSales = 0.0,
    this.orderCount = 0,
    this.salesPerOrder = 0.0,
    this.buyerCount = 0,
    this.salesPerBuyer = 0.0,
    this.conversionRate = 0.0,
    this.salesChartData = const [],
    this.ordersChartData = const [],
    this.salesPerOrderChartData = const [],
    this.buyersChartData = const [],
    this.salesPerBuyerChartData = const [],
    this.conversionRateChartData = const [],
    this.salesPercentageChange = 0.0,
    this.ordersPercentageChange = 0.0,
    this.salesPerOrderPercentageChange = 0.0,
    this.buyersPercentageChange = 0.0,
    this.salesPerBuyerPercentageChange = 0.0,
    this.conversionRatePercentageChange = 0.0,
    this.shopRating = 0.0,
  });
}

class ProductPerformanceData {
  final int totalProducts;
  final int activeProducts;
  final int soldProducts;
  final double totalRevenue;
  final double averagePrice;
  final double averageRating;
  final List<FlSpot> productsChartData;
  final List<FlSpot> revenueChartData;
  final List<FlSpot> ratingChartData;
  final List<FlSpot> soldChartData;
  final List<FlSpot> activeProductsChartData;
  final List<FlSpot> averagePriceChartData;
  final double productsPercentageChange;
  final double revenuePercentageChange;
  final double ratingPercentageChange;
  final double soldPercentageChange;
  final double averagePricePercentageChange;
  final double activeProductsPercentageChange;
  final List<Map<String, dynamic>> topProducts;

  ProductPerformanceData({
    this.totalProducts = 0,
    this.activeProducts = 0,
    this.soldProducts = 0,
    this.totalRevenue = 0.0,
    this.averagePrice = 0.0,
    this.averageRating = 0.0,
    this.productsChartData = const [],
    this.revenueChartData = const [],
    this.ratingChartData = const [],
    this.soldChartData = const [],
    this.activeProductsChartData = const [],
    this.averagePriceChartData = const [],
    this.productsPercentageChange = 0.0,
    this.revenuePercentageChange = 0.0,
    this.ratingPercentageChange = 0.0,
    this.soldPercentageChange = 0.0,
    this.averagePricePercentageChange = 0.0,
    this.activeProductsPercentageChange = 0.0,
    this.topProducts = const [],
  });
}

class _ShopPerformanceScreenState extends State<ShopPerformanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDateIndex = 2; // Default to "Past 7 Days"
  int _selectedMetricIndex = 0; // Default to "Sales"
  int _selectedProductMetricIndex = 0; // Default to "Products"
  late Future<PerformanceData> _performanceDataFuture;
  Future<ProductPerformanceData>? _productPerformanceDataFuture;
  double? _shopRating; // cache for UI

  // Helper: generate chart data
  List<FlSpot> generateChartData(Map<DateTime, dynamic> dailyData) {
    List<FlSpot> chartData = [];
    
    // Create a list of all days in the current period
    List<DateTime> allDays = [];
    DateTime currentDay = DateTime.now();
    
    // For Real-Time (single day), we need to handle it differently
    if (_selectedDateIndex == 0) {
      // Real-Time: just add today
      allDays.add(DateTime(currentDay.year, currentDay.month, currentDay.day));
    } else {
      // For other periods, iterate through all days
      DateTime startDate;
      switch (_selectedDateIndex) {
        case 1: // Yesterday
          startDate = DateTime(currentDay.year, currentDay.month, currentDay.day - 1);
          break;
        case 2: // Past 7 Days
          startDate = currentDay.subtract(const Duration(days: 7));
          break;
        case 3: // Past 30 Days
          startDate = currentDay.subtract(const Duration(days: 30));
          break;
        default:
          startDate = currentDay.subtract(const Duration(days: 7));
      }
      
      currentDay = startDate;
      while (currentDay.isBefore(DateTime.now()) || currentDay.isAtSameMomentAs(DateTime.now())) {
        allDays.add(DateTime(currentDay.year, currentDay.month, currentDay.day));
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }
    
    // Generate chart data for all days, using 0 for days without data
    for (var i = 0; i < allDays.length; i++) {
      final day = allDays[i];
      final value = dailyData[day];
      if (value is num) {
        chartData.add(FlSpot(i.toDouble(), value.toDouble()));
      } else {
        chartData.add(FlSpot(i.toDouble(), 0.0));
      }
    }
    
    // For single data points, create a line segment by adding a second point
    if (chartData.length == 1 && chartData.first.y > 0) {
      chartData.add(FlSpot(1.0, chartData.first.y));
    }
    
    return chartData;
  }

  // Helper function to safely convert Firestore data to numbers
  num safeToNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _performanceDataFuture = _fetchPerformanceData();
    _productPerformanceDataFuture = _fetchProductPerformanceData();
    _trackStoreVisit(); // Track this visit
  }

  Future<PerformanceData> _fetchPerformanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return PerformanceData();

    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime previousStartDate;

    switch (_selectedDateIndex) {
      case 0: // Real-Time (Today)
        startDate = DateTime(now.year, now.month, now.day);
        previousStartDate = startDate.subtract(const Duration(days: 1));
        now = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 1: // Yesterday
        startDate = DateTime(now.year, now.month, now.day - 1);
        previousStartDate = startDate.subtract(const Duration(days: 1));
        now = DateTime(now.year, now.month, now.day);
        break;
      case 2: // Past 7 Days
        startDate = now.subtract(const Duration(days: 7));
        previousStartDate = startDate.subtract(const Duration(days: 7));
        break;
      case 3: // Past 30 Days
        startDate = now.subtract(const Duration(days: 30));
        previousStartDate = startDate.subtract(const Duration(days: 30));
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
        previousStartDate = startDate.subtract(const Duration(days: 7));
    }

    // Fetch current period data
    final currentOrdersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('sellerIds', arrayContains: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    // Fetch previous period data for comparison
    final previousOrdersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('sellerIds', arrayContains: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
        .where('timestamp', isLessThan: Timestamp.fromDate(startDate))
        .get();

    // Calculate current period metrics
    // Data Sources:
    // - Sales: Sum of order totals from 'orders' collection where sellerIds contains current user
    // - Orders: Count of orders from 'orders' collection where sellerIds contains current user  
    // - Buyers: Unique userId values from 'orders' collection where sellerIds contains current user
    // - Sales per Order: Total Sales / Order Count
    // - Sales per Buyer: Total Sales / Unique Buyer Count
    // - Conversion Rate: (Buyers / Estimated Visitors) * 100 (proxy calculation)
    
    double currentTotalSales = 0.0;
    Set<String> currentBuyerIds = {};
    Map<DateTime, double> dailySales = {};
    Map<DateTime, int> dailyOrders = {};
    Map<DateTime, Set<String>> dailyBuyers = {};
    Map<DateTime, double> dailySalesPerOrder = {};
    Map<DateTime, double> dailySalesPerBuyer = {};
    Map<DateTime, double> dailyConversionRate = {};

    for (var doc in currentOrdersSnapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>);
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);

      final buyerId = data['userId'] as String?;
      if(buyerId != null) {
        currentBuyerIds.add(buyerId);
        dailyBuyers[day] = (dailyBuyers[day] ?? <String>{})..add(buyerId);
      }
      
      double orderTotalForSeller = 0;
      for (var item in items) {
        if (item['sellerId'] == user.uid) {
           final price = safeToNum(item['price']);
           final quantity = safeToNum(item['quantity']);
           orderTotalForSeller += price * quantity;
        }
      }
      currentTotalSales += orderTotalForSeller;
      dailySales[day] = (dailySales[day] ?? 0) + orderTotalForSeller;
      dailyOrders[day] = (dailyOrders[day] ?? 0) + 1;
    }

    // Calculate daily metrics
    final sortedDays = dailySales.keys.toList()..sort();
    for (var day in sortedDays) {
      final sales = dailySales[day] ?? 0.0;
      final orders = dailyOrders[day] ?? 0;
      final buyers = dailyBuyers[day]?.length ?? 0;
      
      dailySalesPerOrder[day] = orders > 0 ? sales / orders : 0.0;
      dailySalesPerBuyer[day] = buyers > 0 ? sales / buyers : 0.0;
      dailyConversionRate[day] = buyers > 0 ? (buyers / (buyers + 2)) * 100 : 0.0; // Simplified conversion rate
    }

    final currentOrderCount = currentOrdersSnapshot.docs.length;
    final currentBuyerCount = currentBuyerIds.length;
    final currentSalesPerOrder = currentOrderCount > 0 ? currentTotalSales / currentOrderCount : 0.0;
    final currentSalesPerBuyer = currentBuyerCount > 0 ? currentTotalSales / currentBuyerCount : 0.0;

    // Calculate previous period metrics
    double previousTotalSales = 0.0;
    Set<String> previousBuyerIds = {};
    Map<DateTime, double> previousDailySales = {};
    Map<DateTime, int> previousDailyOrders = {};
    Map<DateTime, Set<String>> previousDailyBuyers = {};
    Map<DateTime, double> previousDailySalesPerOrder = {};
    Map<DateTime, double> previousDailySalesPerBuyer = {};
    Map<DateTime, double> previousDailyConversionRate = {};

    for (var doc in previousOrdersSnapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>);
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
      
      final buyerId = data['userId'] as String?;
      if(buyerId != null) {
        previousBuyerIds.add(buyerId);
        previousDailyBuyers[day] = (previousDailyBuyers[day] ?? <String>{})..add(buyerId);
      }
      
      double orderTotalForSeller = 0;
      for (var item in items) {
        if (item['sellerId'] == user.uid) {
           final price = safeToNum(item['price']);
           final quantity = safeToNum(item['quantity']);
           orderTotalForSeller += price * quantity;
        }
      }
      previousTotalSales += orderTotalForSeller;
      previousDailySales[day] = (previousDailySales[day] ?? 0) + orderTotalForSeller;
      previousDailyOrders[day] = (previousDailyOrders[day] ?? 0) + 1;
    }

    // Calculate previous daily metrics
    final previousSortedDays = previousDailySales.keys.toList()..sort();
    for (var day in previousSortedDays) {
      final sales = previousDailySales[day] ?? 0.0;
      final orders = previousDailyOrders[day] ?? 0;
      final buyers = previousDailyBuyers[day]?.length ?? 0;
      
      previousDailySalesPerOrder[day] = orders > 0 ? sales / orders : 0.0;
      previousDailySalesPerBuyer[day] = buyers > 0 ? sales / buyers : 0.0;
      previousDailyConversionRate[day] = buyers > 0 ? (buyers / (buyers + 2)) * 100 : 0.0;
    }

    final previousOrderCount = previousOrdersSnapshot.docs.length;
    final previousBuyerCount = previousBuyerIds.length;
    final previousSalesPerOrder = previousOrderCount > 0 ? previousTotalSales / previousOrderCount : 0.0;
    final previousSalesPerBuyer = previousBuyerCount > 0 ? previousTotalSales / previousBuyerCount : 0.0;

    // Calculate conversion rate (simplified - using buyer count as proxy for conversion)
    // In a real app, you'd fetch actual visitor data from analytics
    // For now, we'll use a more realistic proxy based on buyer count and time period
    double calculateConversionRate(int buyerCount, int daysInPeriod) {
      if (buyerCount == 0) return 0.0;
      
      // Estimate visitors based on period length and buyer count
      // This is a simplified proxy - in production, use actual analytics data
      double estimatedVisitors;
      switch (daysInPeriod) {
        case 1: // Real-Time or Yesterday
          estimatedVisitors = buyerCount * 20; // Assume 20 visitors per buyer for single day
          break;
        case 7: // Past 7 Days
          estimatedVisitors = buyerCount * 15; // Assume 15 visitors per buyer for week
          break;
        case 30: // Past 30 Days
          estimatedVisitors = buyerCount * 10; // Assume 10 visitors per buyer for month
          break;
        default:
          estimatedVisitors = buyerCount * 12;
      }
      
      return (buyerCount / estimatedVisitors) * 100;
    }

    // Try to fetch real analytics data for conversion rate
    double currentConversionRate = 0.0;
    double previousConversionRate = 0.0;
    
    try {
      // Fetch current period analytics
      final currentAnalyticsSnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .doc(user.uid)
          .collection('visitors')
          .get();
      
      int currentPeriodVisitors = 0;
      int previousPeriodVisitors = 0;
      
      for (var doc in currentAnalyticsSnapshot.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            final visitorCount = safeToNum(data['visitorCount']);
            if (date.isAfter(startDate.subtract(const Duration(days: 1))) && date.isBefore(now.add(const Duration(days: 1)))) {
              currentPeriodVisitors += visitorCount.toInt();
            } else if (date.isAfter(previousStartDate.subtract(const Duration(days: 1))) && date.isBefore(startDate)) {
              previousPeriodVisitors += visitorCount.toInt();
            }
          }
        }
      }
      
      // Calculate real conversion rates if we have visitor data
      if (currentPeriodVisitors > 0) {
        currentConversionRate = (currentBuyerCount / currentPeriodVisitors) * 100;
      } else {
        currentConversionRate = calculateConversionRate(currentBuyerCount, _selectedDateIndex == 0 || _selectedDateIndex == 1 ? 1 : _selectedDateIndex == 2 ? 7 : 30);
      }
      
      if (previousPeriodVisitors > 0) {
        previousConversionRate = (previousBuyerCount / previousPeriodVisitors) * 100;
      } else {
        previousConversionRate = calculateConversionRate(previousBuyerCount, _selectedDateIndex == 0 || _selectedDateIndex == 1 ? 1 : _selectedDateIndex == 2 ? 7 : 30);
      }
      
    } catch (e) {
      // Fall back to proxy calculation if analytics fetch fails
      currentConversionRate = calculateConversionRate(currentBuyerCount, _selectedDateIndex == 0 || _selectedDateIndex == 1 ? 1 : _selectedDateIndex == 2 ? 7 : 30);
      previousConversionRate = calculateConversionRate(previousBuyerCount, _selectedDateIndex == 0 || _selectedDateIndex == 1 ? 1 : _selectedDateIndex == 2 ? 7 : 30);
    }

    // Calculate percentage changes
    double calculatePercentageChange(double current, double previous) {
      if (previous == 0) return current > 0 ? 100.0 : 0.0;
      return ((current - previous) / previous) * 100;
    }

    final salesPercentageChange = calculatePercentageChange(currentTotalSales, previousTotalSales);
    final ordersPercentageChange = calculatePercentageChange(currentOrderCount.toDouble(), previousOrderCount.toDouble());
    final salesPerOrderPercentageChange = calculatePercentageChange(currentSalesPerOrder, previousSalesPerOrder);
    final buyersPercentageChange = calculatePercentageChange(currentBuyerCount.toDouble(), previousBuyerCount.toDouble());
    final salesPerBuyerPercentageChange = calculatePercentageChange(currentSalesPerBuyer, previousSalesPerBuyer);
    final conversionRatePercentageChange = calculatePercentageChange(currentConversionRate, previousConversionRate);

    // Generate chart data for all metrics
    List<FlSpot> salesChartData = generateChartData(dailySales);
    List<FlSpot> ordersChartData = generateChartData(dailyOrders);
    List<FlSpot> salesPerOrderChartData = generateChartData(dailySalesPerOrder);
    List<FlSpot> buyersChartData = generateChartData(dailyBuyers.map((k, v) => MapEntry(k, v.length.toDouble())));
    List<FlSpot> salesPerBuyerChartData = generateChartData(dailySalesPerBuyer);
    List<FlSpot> conversionRateChartData = generateChartData(dailyConversionRate);

    // At the end, fetch real shop rating
    final shopRating = await _fetchShopRating(user.uid);
    _shopRating = shopRating;

    return PerformanceData(
      totalSales: currentTotalSales,
      orderCount: currentOrderCount,
      buyerCount: currentBuyerCount,
      salesPerOrder: currentSalesPerOrder,
      salesPerBuyer: currentSalesPerBuyer,
      salesChartData: salesChartData,
      ordersChartData: ordersChartData,
      salesPerOrderChartData: salesPerOrderChartData,
      buyersChartData: buyersChartData,
      salesPerBuyerChartData: salesPerBuyerChartData,
      conversionRateChartData: conversionRateChartData,
      conversionRate: currentConversionRate,
      salesPercentageChange: salesPercentageChange.isNaN ? 0.0 : salesPercentageChange,
      ordersPercentageChange: ordersPercentageChange.isNaN ? 0.0 : ordersPercentageChange,
      salesPerOrderPercentageChange: salesPerOrderPercentageChange.isNaN ? 0.0 : salesPerOrderPercentageChange,
      buyersPercentageChange: buyersPercentageChange.isNaN ? 0.0 : buyersPercentageChange,
      salesPerBuyerPercentageChange: salesPerBuyerPercentageChange.isNaN ? 0.0 : salesPerBuyerPercentageChange,
      conversionRatePercentageChange: conversionRatePercentageChange.isNaN ? 0.0 : conversionRatePercentageChange,
      shopRating: shopRating,
    );
  }

  Future<ProductPerformanceData> _fetchProductPerformanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return ProductPerformanceData();

    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime previousStartDate;

    switch (_selectedDateIndex) {
      case 0: // Real-Time (Today)
        startDate = DateTime(now.year, now.month, now.day);
        previousStartDate = startDate.subtract(const Duration(days: 1));
        now = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 1: // Yesterday
        startDate = DateTime(now.year, now.month, now.day - 1);
        previousStartDate = startDate.subtract(const Duration(days: 1));
        now = DateTime(now.year, now.month, now.day);
        break;
      case 2: // Past 7 Days
        startDate = now.subtract(const Duration(days: 7));
        previousStartDate = startDate.subtract(const Duration(days: 7));
        break;
      case 3: // Past 30 Days
        startDate = now.subtract(const Duration(days: 30));
        previousStartDate = startDate.subtract(const Duration(days: 30));
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
        previousStartDate = startDate.subtract(const Duration(days: 7));
    }

    // Fetch current period products
    final currentProductsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: user.uid)
        .get();

    // Fetch current period orders for revenue calculation
    final currentOrdersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('sellerIds', arrayContains: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    // Fetch previous period orders for comparison
    final previousOrdersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('sellerIds', arrayContains: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
        .where('timestamp', isLessThan: Timestamp.fromDate(startDate))
        .get();

    // Fetch previous period products for comparison
    final previousProductsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: user.uid)
        .get();

    // Filter products by date if createdAt field exists, otherwise use all products
    final currentProducts = currentProductsSnapshot.docs.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final createdDate = createdAt.toDate();
        return createdDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
               createdDate.isBefore(now.add(const Duration(days: 1)));
      }
      // If no createdAt field, include all products for current period
      return true;
    }).toList();

    final previousProducts = previousProductsSnapshot.docs.where((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final createdDate = createdAt.toDate();
        return createdDate.isAfter(previousStartDate.subtract(const Duration(days: 1))) && 
               createdDate.isBefore(startDate);
      }
      // If no createdAt field, use a different approach - compare active products
      return false; // Don't include in previous period if no createdAt
    }).toList();

    // Check if we have createdAt field in products
    final hasCreatedAtField = currentProductsSnapshot.docs.isNotEmpty && 
                              currentProductsSnapshot.docs.first.data().containsKey('createdAt');
    
    if (kDebugMode) {
      print('Has createdAt field: $hasCreatedAtField');
      print('Total products in collection: ${currentProductsSnapshot.docs.length}');
      print('Filtered current products: ${currentProducts.length}');
      print('Filtered previous products: ${previousProducts.length}');
    }

    // Alternative approach: If no createdAt field or no previous products, use performance comparison
    // This compares how the same products performed in current vs previous period
    bool usePerformanceComparison = !hasCreatedAtField || previousProducts.isEmpty;
    
    if (usePerformanceComparison) {
      if (kDebugMode) {
        print('Using performance comparison approach');
      }
    }

    // Calculate current period metrics
    int totalProducts = currentProducts.length;
    int activeProducts = 0;
    double totalRevenue = 0.0;
    double totalPrice = 0.0;
    double totalRating = 0.0;
    int ratedProducts = 0;
    
    // Maps to track product performance from orders (more accurate than product.sold field)
    Map<String, int> productSales = {};
    Map<String, double> productRevenue = {};
    Map<String, double> productPrices = {}; // Store actual prices from orders
    Map<DateTime, int> dailyProducts = {};
    Map<DateTime, double> dailyRevenue = {};
    Map<DateTime, double> _ = {};
    Map<DateTime, int> dailySold = {};
    Map<DateTime, int> dailyActiveProducts = {}; // Daily active products (with stock > 0)

    // Process products for basic metrics
    for (var doc in currentProducts) {
      final data = doc.data();
      final price = safeToNum(data['price']);
      final rating = safeToNum(data['rating']);
      final quantity = safeToNum(data['quantity']);
      
      totalPrice += price;
      if (quantity > 0) activeProducts++;
      if (rating > 0) {
        totalRating += rating;
        ratedProducts++;
      }
      
      // Initialize product tracking maps
      productSales[doc.id] = 0;
      productRevenue[doc.id] = 0.0;
      productPrices[doc.id] = price.toDouble();
    }

    // Process orders for accurate sales and revenue data
    for (var doc in currentOrdersSnapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>);
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);

      for (var item in items) {
        if (item['sellerId'] == user.uid) {
          final price = safeToNum(item['price']);
          final quantity = safeToNum(item['quantity']);
          final productId = item['productId'] as String?;
          
          totalRevenue += price * quantity;
          
          if (productId != null) {
            productSales[productId] = (productSales[productId] ?? 0) + quantity.toInt();
            productRevenue[productId] = (productRevenue[productId] ?? 0) + (price * quantity);
          }
          
          dailyRevenue[day] = (dailyRevenue[day] ?? 0) + (price * quantity);
          dailySold[day] = (dailySold[day] ?? 0) + quantity.toInt();
        }
      }
    }

    // Calculate daily metrics with real data
    final sortedDays = dailyRevenue.keys.toList()..sort();
    
    // For products chart: show daily unique products sold (different products sold each day)
    Map<DateTime, Set<String>> dailySoldProductIds = {};
    
    // Track which products were sold each day
    for (var doc in currentOrdersSnapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>);
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
      
      for (var item in items) {
        if (item['sellerId'] == user.uid) {
          final productId = item['productId'] as String?;
          if (productId != null) {
            dailySoldProductIds[day] = (dailySoldProductIds[day] ?? <String>{})..add(productId);
          }
        }
      }
    }
    
    // Convert to daily unique products sold counts
    for (var day in sortedDays) {
      dailyProducts[day] = dailySoldProductIds[day]?.length ?? 0;
    }
    
    // For active products chart: show daily products with stock > 0
    // This will be a static count for each day since inventory doesn't change daily
    int totalActiveProducts = 0;
    for (var doc in currentProducts) {
      final data = doc.data();
      final quantity = safeToNum(data['quantity']);
      if (quantity > 0) {
        totalActiveProducts++;
      }
    }
    
    // Set the same active count for all days (since inventory is static)
    // But also include days with 0 sales to show the flat line pattern
    for (var day in sortedDays) {
      dailyActiveProducts[day] = totalActiveProducts;
    }
    
    // Also add the active count for days without sales to show a continuous flat line
    // This will make the Active chart look like a flat line instead of scattered points
    DateTime currentDay = startDate;
    while (currentDay.isBefore(now) || currentDay.isAtSameMomentAs(now)) {
      final day = DateTime(currentDay.year, currentDay.month, currentDay.day);
      if (!dailyActiveProducts.containsKey(day)) {
        dailyActiveProducts[day] = totalActiveProducts;
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }
    
    // For rating chart: calculate daily average rating from ratings subcollection
    // This will be populated later when we fetch rating data
    Map<DateTime, double> dailyRatingData = {};
    
    // Initialize daily rating data with 0 for days with sales
    for (var day in sortedDays) {
      dailyRatingData[day] = 0.0;
    }

    // Calculate daily average price from orders
    Map<DateTime, double> dailyAveragePrice = {};
    Map<DateTime, double> dailyTotalPrice = {};
    Map<DateTime, int> dailyTotalQuantity = {};
    
    // Process orders to calculate daily average price
    for (var doc in currentOrdersSnapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>);
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final day = DateTime(timestamp.year, timestamp.month, timestamp.day);

      for (var item in items) {
        if (item['sellerId'] == user.uid) {
          final price = safeToNum(item['price']);
          final quantity = safeToNum(item['quantity']);
          
          dailyTotalPrice[day] = (dailyTotalPrice[day] ?? 0) + (price * quantity);
          dailyTotalQuantity[day] = (dailyTotalQuantity[day] ?? 0) + quantity.toInt();
        }
      }
    }
    
    // Calculate daily average price
    for (var day in sortedDays) {
      final totalPrice = dailyTotalPrice[day] ?? 0.0;
      final totalQuantity = dailyTotalQuantity[day] ?? 0;
      dailyAveragePrice[day] = totalQuantity > 0 ? totalPrice / totalQuantity : 0.0;
    }

    // Calculate averages
    final averagePrice = totalProducts > 0 ? totalPrice / totalProducts : 0.0;
    final averageRating = ratedProducts > 0 ? totalRating / ratedProducts : 0.0;
    final soldProducts = productSales.values.fold(0, (sum, sold) => sum + sold);

    // Calculate previous period metrics for comparison
    double previousRevenue = 0.0;
    int previousSoldProducts = 0;
    int previousTotalProducts = previousProducts.length;
    int previousActiveProducts = 0;
    double previousTotalPrice = 0.0;
    double previousTotalRating = 0.0;
    int previousRatedProducts = 0;
    
    // Process previous period products
    for (var doc in previousProducts) {
      final data = doc.data();
      final price = safeToNum(data['price']);
      final rating = safeToNum(data['rating']);
      final quantity = safeToNum(data['quantity']);
      
      previousTotalPrice += price;
      if (quantity > 0) previousActiveProducts++;
      if (rating > 0) {
        previousTotalRating += rating;
        previousRatedProducts++;
      }
    }
    
    // Process previous period orders
    for (var doc in previousOrdersSnapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List<dynamic>);
      
      for (var item in items) {
        if (item['sellerId'] == user.uid) {
          final price = safeToNum(item['price']);
          final quantity = safeToNum(item['quantity']);
          previousRevenue += price * quantity;
          previousSoldProducts += quantity.toInt();
        }
      }
    }

    // Calculate previous period averages
    final previousAveragePrice = previousTotalProducts > 0 ? previousTotalPrice / previousTotalProducts : 0.0;
    final previousAverageRating = previousRatedProducts > 0 ? previousTotalRating / previousRatedProducts : 0.0;

    // Fetch actual rating data from ratings subcollection for proper comparison
    double currentPeriodAverageRating = 0.0;
    double previousPeriodAverageRating = 0.0;
    
    try {
      // Get all product IDs for this seller
      final allProductIds = currentProductsSnapshot.docs.map((doc) => doc.id).toList();
      
      if (allProductIds.isNotEmpty) {
        // Fetch current period ratings
        double currentTotalRating = 0.0;
        int currentRatingCount = 0;
        
        // Fetch previous period ratings
        double previousTotalRating = 0.0;
        int previousRatingCount = 0;
        
        // For daily rating calculation
        Map<DateTime, List<double>> dailyRatings = {};
        
        for (String productId in allProductIds) {
          // Fetch ratings for this product
          final ratingsSnapshot = await FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .collection('ratings')
              .get();
          
          for (var ratingDoc in ratingsSnapshot.docs) {
            final ratingData = ratingDoc.data();
            final rating = safeToNum(ratingData['rating']);
            final timestamp = ratingData['timestamp'] as Timestamp?;
            
            if (rating > 0 && timestamp != null) {
              final ratingDate = timestamp.toDate();
              final day = DateTime(ratingDate.year, ratingDate.month, ratingDate.day);
              
              // Check if rating is in current period
              if (ratingDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
                  ratingDate.isBefore(now.add(const Duration(days: 1)))) {
                currentTotalRating += rating;
                currentRatingCount++;
                
                // Add to daily ratings for chart
                dailyRatings[day] = (dailyRatings[day] ?? [])..add(rating.toDouble());
              }
              
              // Check if rating is in previous period
              if (ratingDate.isAfter(previousStartDate.subtract(const Duration(days: 1))) && 
                  ratingDate.isBefore(startDate)) {
                previousTotalRating += rating;
                previousRatingCount++;
              }
            }
          }
        }
        
        // Calculate daily average ratings
        for (var entry in dailyRatings.entries) {
          final day = entry.key;
          final ratings = entry.value;
          if (ratings.isNotEmpty) {
            final dailyAverage = ratings.reduce((a, b) => a + b) / ratings.length;
            dailyRatingData[day] = dailyAverage;
          }
        }
        
        currentPeriodAverageRating = currentRatingCount > 0 ? currentTotalRating / currentRatingCount : 0.0;
        previousPeriodAverageRating = previousRatingCount > 0 ? previousTotalRating / previousRatingCount : 0.0;
        
        if (kDebugMode) {
          print('Rating Analysis - Current Period: $currentRatingCount ratings, avg: $currentPeriodAverageRating');
          print('Rating Analysis - Previous Period: $previousRatingCount ratings, avg: $previousPeriodAverageRating');
          print('Daily Ratings Data: $dailyRatingData');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching rating data: $e');
      }
      // Fall back to product-level ratings
      currentPeriodAverageRating = averageRating;
      previousPeriodAverageRating = previousAverageRating;
    }

    // Calculate percentage changes
    double calculatePercentageChange(double current, double previous) {
      if (previous == 0) return current > 0 ? 100.0 : 0.0;
      return ((current - previous) / previous) * 100;
    }

    double revenuePercentageChange;
    double soldPercentageChange;
    double productsPercentageChange;
    double activeProductsPercentageChange;
    double averagePricePercentageChange;
    double ratingPercentageChange;

    if (usePerformanceComparison) {
      // Compare performance of same products in different periods
      // For products count and active products, we can't compare directly
      // So we'll show 0% change or compare based on availability
      productsPercentageChange = 0.0; // Products count doesn't change in performance comparison
      
      // For active products, compare current vs previous period active counts
      // Calculate current period active products (products with stock or sales)
      int currentPeriodActiveProducts = 0;
      for (var doc in currentProducts) {
        final data = doc.data();
        final quantity = safeToNum(data['quantity']);
        if (quantity > 0) {
          currentPeriodActiveProducts++;
        }
      }
      
      // Calculate previous period active products
      int previousPeriodActiveProducts = 0;
      for (var doc in previousProducts) {
        final data = doc.data();
        final quantity = safeToNum(data['quantity']);
        if (quantity > 0) {
          previousPeriodActiveProducts++;
        }
      }
      
      activeProductsPercentageChange = calculatePercentageChange(currentPeriodActiveProducts.toDouble(), previousPeriodActiveProducts.toDouble());
      
      // For revenue, sold, average price, and rating, we can compare performance
      revenuePercentageChange = calculatePercentageChange(totalRevenue, previousRevenue);
      soldPercentageChange = calculatePercentageChange(soldProducts.toDouble(), previousSoldProducts.toDouble());
      averagePricePercentageChange = calculatePercentageChange(averagePrice, previousAveragePrice);
      ratingPercentageChange = calculatePercentageChange(currentPeriodAverageRating, previousPeriodAverageRating);
      
      if (kDebugMode) {
        print('Using performance comparison - comparing same products performance across periods');
        print('Active Products - Current: $currentPeriodActiveProducts, Previous: $previousPeriodActiveProducts, Change: ${activeProductsPercentageChange.toStringAsFixed(2)}%');
      }
    } else {
      // Use the original approach with filtered products by date
      revenuePercentageChange = calculatePercentageChange(totalRevenue, previousRevenue);
      soldPercentageChange = calculatePercentageChange(soldProducts.toDouble(), previousSoldProducts.toDouble());
      productsPercentageChange = calculatePercentageChange(totalProducts.toDouble(), previousTotalProducts.toDouble());
      activeProductsPercentageChange = calculatePercentageChange(activeProducts.toDouble(), previousActiveProducts.toDouble());
      averagePricePercentageChange = calculatePercentageChange(averagePrice, previousAveragePrice);
      ratingPercentageChange = calculatePercentageChange(currentPeriodAverageRating, previousPeriodAverageRating);
      
      if (kDebugMode) {
        print('Using date-based product comparison');
      }
    }

    // Debug information
    if (kDebugMode) {
      print('=== Product Performance Debug ===');
      print('Current Period: ${startDate.toIso8601String()} to ${now.toIso8601String()}');
      print('Previous Period: ${previousStartDate.toIso8601String()} to ${startDate.toIso8601String()}');
      print('Current - Total Products: $totalProducts, Active: $activeProducts, Revenue: $totalRevenue, Sold: $soldProducts, Avg Price: $averagePrice, Avg Rating: $averageRating');
      print('Previous - Total Products: $previousTotalProducts, Active: $previousActiveProducts, Revenue: $previousRevenue, Sold: $previousSoldProducts, Avg Price: $previousAveragePrice, Avg Rating: $previousAverageRating');
      print('Rating Analysis - Current Period Avg: $currentPeriodAverageRating, Previous Period Avg: $previousPeriodAverageRating');
      print('Percentage Changes - Products: ${productsPercentageChange.toStringAsFixed(2)}%, Active: ${activeProductsPercentageChange.toStringAsFixed(2)}%, Revenue: ${revenuePercentageChange.toStringAsFixed(2)}%, Sold: ${soldPercentageChange.toStringAsFixed(2)}%, Avg Price: ${averagePricePercentageChange.toStringAsFixed(2)}%, Rating: ${ratingPercentageChange.toStringAsFixed(2)}%');
      print('Current Products Count: ${currentProducts.length}, Previous Products Count: ${previousProducts.length}');
      print('=== Chart Data Debug ===');
      print('Daily Revenue Data: $dailyRevenue');
      print('Daily Sold Data: $dailySold');
      print('Daily Products Data: $dailyProducts');
      print('Daily Active Products Data: $dailyActiveProducts');
      print('Daily Rating Data: $dailyRatingData');
      print('Daily Sold Product IDs: $dailySoldProductIds');
    }

    // Generate chart data
    final productsChartData = generateChartData(dailyProducts);
    final revenueChartData = generateChartData(dailyRevenue);
    final ratingChartData = generateChartData(dailyRatingData);
    final soldChartData = generateChartData(dailySold);
    final activeProductsChartData = generateChartData(dailyActiveProducts);
    final averagePriceChartData = generateChartData(dailyAveragePrice);

    // Debug chart data
    if (kDebugMode) {
      print('=== Chart Data Generation Debug ===');
      print('Products Chart Data: $productsChartData');
      print('Active Products Chart Data: $activeProductsChartData');
      print('Daily Products Map: $dailyProducts');
      print('Daily Active Products Map: $dailyActiveProducts');
      print('Total Active Products Count: $totalActiveProducts');
      print('Daily Sold Product IDs: $dailySoldProductIds');
      print('=== Chart Pattern Analysis ===');
      print('Products Chart Pattern: Shows daily unique products sold (dynamic)');
      print('Active Chart Pattern: Shows current inventory count (static flat line)');
      print('Products Values: ${dailyProducts.values.toList()}');
      print('Active Values: ${dailyActiveProducts.values.toList()}');
    }

    // Get top products by revenue (using order data for accuracy)
    final topProducts = productRevenue.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
          QueryDocumentSnapshot<Map<String, dynamic>>? productDoc;
          try {
            productDoc = currentProducts
                .firstWhere((doc) => doc.id == entry.key);
          } catch (e) {
            // If product not found, skip this entry
            return null;
          }
          
          final productData = productDoc.data();
          return {
            'id': entry.key,
            'name': productData['name'] ?? 'Unknown Product',
            'revenue': entry.value,
            'sold': productSales[entry.key] ?? 0,
            'price': productPrices[entry.key] ?? 0.0, // Use stored price from orders
            'image': (productData['imageUrls'] as List?)?.firstOrNull ?? '',
          };
        })
        .where((product) => product != null)
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    return ProductPerformanceData(
      totalProducts: totalProducts,
      activeProducts: activeProducts,
      soldProducts: soldProducts,
      totalRevenue: totalRevenue,
      averagePrice: averagePrice,
      averageRating: currentPeriodAverageRating,
      productsChartData: productsChartData,
      revenueChartData: revenueChartData,
      ratingChartData: ratingChartData,
      soldChartData: soldChartData,
      activeProductsChartData: activeProductsChartData,
      averagePriceChartData: averagePriceChartData,
      productsPercentageChange: productsPercentageChange,
      revenuePercentageChange: revenuePercentageChange,
      ratingPercentageChange: ratingPercentageChange,
      soldPercentageChange: soldPercentageChange,
      averagePricePercentageChange: averagePricePercentageChange,
      activeProductsPercentageChange: activeProductsPercentageChange,
      topProducts: topProducts.take(5).toList(),
    );
  }

  // Helper: fetch real shop rating
  Future<double> _fetchShopRating(String sellerId) async {
    final ratingsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .collection('shop_ratings')
        .get();
    if (ratingsSnapshot.docs.isEmpty) return 0.0;
    double total = 0.0;
    int count = 0;
    for (var doc in ratingsSnapshot.docs) {
      final rating = (doc.data()['rating'] ?? 0).toDouble();
      if (rating > 0) {
        total += rating;
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  void _updateData() {
    setState(() {
      _performanceDataFuture = _fetchPerformanceData();
      _productPerformanceDataFuture = _fetchProductPerformanceData();
    });
  }

  // Track store visit for analytics
  Future<void> _trackStoreVisit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      await FirebaseFirestore.instance
          .collection('analytics')
          .doc(user.uid)
          .collection('visitors')
          .doc(dateKey)
          .set({
        'date': dateKey,
        'visitorCount': FieldValue.increment(1),
        'lastVisit': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently fail - analytics tracking shouldn't break the app
      if (kDebugMode) {
        print('Analytics tracking failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shop Performance', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blueAccent,
          tabs: [
            Tab(child: Text('Sales', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600))),
            Tab(child: Text('Product', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesView(),
          _buildProductView(),
        ],
      ),
    );
  }

  Widget _buildSalesView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<PerformanceData>(
          future: _performanceDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('No data available.'));
            }

            final data = snapshot.data!;

            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date Period', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 35,
                    child: _buildDatePeriodSelector(),
                  ),
                  const SizedBox(height: 20),
                  _buildMetricsGrid(data),
                  const SizedBox(height: 16),
                  _buildSalesChart(data),
                  const SizedBox(height: 24),
                  _buildPerformanceData(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDatePeriodSelector() {
    final periods = ['Real-Time', 'Yesterday', 'Past 7 Days', 'Past 30 Days'];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate button width based on available space, ensuring it's not negative
        final availableWidth = constraints.maxWidth - 36; // 36 for spacing between buttons
        final buttonWidth = availableWidth > 0 ? availableWidth / 4 : 80.0; // fallback width
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: periods.asMap().entries.map((entry) {
            final index = entry.key;
            final period = entry.value;
            return SizedBox(
              width: buttonWidth,
              height: 35,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedDateIndex = index;
                    _updateData();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedDateIndex == index ? Colors.blueAccent : Colors.white,
                  foregroundColor: _selectedDateIndex == index ? Colors.white : Colors.blueAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: _selectedDateIndex == index ? Colors.blueAccent : Colors.grey[300]!,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                child: Text(
                  period,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMetricsGrid(PerformanceData data) {
    String formatPercentage(double value) {
      if (value.isNaN || value.isInfinite) return '0.0%';
      return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1.2,
      children: [
        _MetricCard(
          title: 'Sales', 
          value: 'RM${data.totalSales.toStringAsFixed(2)}', 
          change: formatPercentage(data.salesPercentageChange), 
          isUp: data.salesPercentageChange >= 0, 
          isSelected: _selectedMetricIndex == 0,
          onTap: () {
            setState(() {
              _selectedMetricIndex = 0;
            });
          },
        ),
        _MetricCard(
          title: 'Orders', 
          value: data.orderCount.toString(), 
          change: formatPercentage(data.ordersPercentageChange), 
          isUp: data.ordersPercentageChange >= 0,
          isSelected: _selectedMetricIndex == 1,
          onTap: () {
            setState(() {
              _selectedMetricIndex = 1;
            });
          },
        ),
        _MetricCard(
          title: 'Sales per Order', 
          value: 'RM${data.salesPerOrder.toStringAsFixed(2)}', 
          change: formatPercentage(data.salesPerOrderPercentageChange), 
          isUp: data.salesPerOrderPercentageChange >= 0,
          isSelected: _selectedMetricIndex == 2,
          onTap: () {
            setState(() {
              _selectedMetricIndex = 2;
            });
          },
        ),
        _MetricCard(
          title: 'Buyers', 
          value: data.buyerCount.toString(), 
          change: formatPercentage(data.buyersPercentageChange), 
          isUp: data.buyersPercentageChange >= 0,
          isSelected: _selectedMetricIndex == 3,
          onTap: () {
            setState(() {
              _selectedMetricIndex = 3;
            });
          },
        ),
        _MetricCard(
          title: 'Sales per Buyer', 
          value: 'RM${data.salesPerBuyer.toStringAsFixed(2)}', 
          change: formatPercentage(data.salesPerBuyerPercentageChange), 
          isUp: data.salesPerBuyerPercentageChange >= 0,
          isSelected: _selectedMetricIndex == 4,
          onTap: () {
            setState(() {
              _selectedMetricIndex = 4;
            });
          },
        ),
        _MetricCard(
          title: 'Conversion Rate', 
          value: '${data.conversionRate.toStringAsFixed(2)}%', 
          change: formatPercentage(data.conversionRatePercentageChange), 
          isUp: data.conversionRatePercentageChange >= 0,
          isSelected: _selectedMetricIndex == 5,
          onTap: () {
            setState(() {
              _selectedMetricIndex = 5;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSalesChart(PerformanceData data) {
    List<FlSpot> getSelectedMetricData() {
      switch (_selectedMetricIndex) {
        case 0: return data.salesChartData;
        case 1: return data.ordersChartData;
        case 2: return data.salesPerOrderChartData;
        case 3: return data.buyersChartData;
        case 4: return data.salesPerBuyerChartData;
        case 5: return data.conversionRateChartData;
        default: return data.salesChartData;
      }
    }

    String getMetricTitle() {
      switch (_selectedMetricIndex) {
        case 0: return 'Sales';
        case 1: return 'Orders';
        case 2: return 'Sales per Order';
        case 3: return 'Buyers';
        case 4: return 'Sales per Buyer';
        case 5: return 'Conversion Rate';
        default: return 'Sales';
      }
    }

    final spots = getSelectedMetricData();
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getMetricTitle(),
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: spots.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No data available for selected period',
                        style: GoogleFonts.dmSans(
                          fontSize: 14, 
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1.0,
                    minY: 0,
                    maxY: spots.isNotEmpty ? spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.1 : 100.0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.orange,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [Colors.orange.withOpacity(0.3), Colors.orange.withOpacity(0.0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter
                          )
                        )
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceData() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
         boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('Performance Data', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
           const SizedBox(height: 16),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceAround,
             children: [
                _PerformanceDataItem(value: (_shopRating?.toStringAsFixed(1) ?? '0.0'), label: '/ 5.0', description: 'Shop Rating'),
                Container(width: 1, height: 40, color: Colors.grey[200]),
               _PerformanceDataItem(value: 'Good', label: '', description: 'Account Health'),
             ],
           ),
        ],
      ),
    );
  }

  Widget _buildProductView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<ProductPerformanceData>(
          future: _productPerformanceDataFuture ?? Future.value(ProductPerformanceData()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('No data available.'));
            }

            final data = snapshot.data!;

            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date Period', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 35,
                    child: _buildDatePeriodSelector(),
                  ),
                  const SizedBox(height: 20),
                  _buildProductMetricsGrid(data),
                  const SizedBox(height: 16),
                  _buildProductChart(data),
                  const SizedBox(height: 24),
                  _buildTopProducts(data),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductMetricsGrid(ProductPerformanceData data) {
    String formatPercentage(double value) {
      if (value.isNaN || value.isInfinite) return '0.0%';
      return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1.2,
      children: [
        _MetricCard(
          title: 'Products', 
          value: data.totalProducts.toString(), 
          change: formatPercentage(data.productsPercentageChange), 
          isUp: data.productsPercentageChange >= 0, 
          isSelected: _selectedProductMetricIndex == 0,
          onTap: () {
            setState(() {
              _selectedProductMetricIndex = 0;
            });
          },
        ),
        _MetricCard(
          title: 'Revenue', 
          value: 'RM${data.totalRevenue.toStringAsFixed(2)}', 
          change: formatPercentage(data.revenuePercentageChange), 
          isUp: data.revenuePercentageChange >= 0,
          isSelected: _selectedProductMetricIndex == 1,
          onTap: () {
            setState(() {
              _selectedProductMetricIndex = 1;
            });
          },
        ),
        _MetricCard(
          title: 'Sold', 
          value: data.soldProducts.toString(), 
          change: formatPercentage(data.soldPercentageChange), 
          isUp: data.soldPercentageChange >= 0,
          isSelected: _selectedProductMetricIndex == 2,
          onTap: () {
            setState(() {
              _selectedProductMetricIndex = 2;
            });
          },
        ),
        _MetricCard(
          title: 'Avg Price', 
          value: 'RM${data.averagePrice.toStringAsFixed(2)}', 
          change: formatPercentage(data.averagePricePercentageChange), 
          isUp: data.averagePricePercentageChange >= 0,
          isSelected: _selectedProductMetricIndex == 3,
          onTap: () {
            setState(() {
              _selectedProductMetricIndex = 3;
            });
          },
        ),
        _MetricCard(
          title: 'Active', 
          value: data.activeProducts.toString(), 
          change: formatPercentage(data.activeProductsPercentageChange), 
          isUp: data.activeProductsPercentageChange >= 0,
          isSelected: _selectedProductMetricIndex == 4,
          onTap: () {
            setState(() {
              _selectedProductMetricIndex = 4;
            });
          },
        ),
        _MetricCard(
          title: 'Rating', 
          value: data.averageRating.toStringAsFixed(1), 
          change: formatPercentage(data.ratingPercentageChange), 
          isUp: data.ratingPercentageChange >= 0,
          isSelected: _selectedProductMetricIndex == 5,
          onTap: () {
            setState(() {
              _selectedProductMetricIndex = 5;
            });
          },
        ),
      ],
    );
  }

  Widget _buildProductChart(ProductPerformanceData data) {
    List<FlSpot> getSelectedMetricData() {
      switch (_selectedProductMetricIndex) {
        case 0: return data.productsChartData;
        case 1: return data.revenueChartData;
        case 2: return data.soldChartData;
        case 3: return data.averagePriceChartData; // Average Price
        case 4: return data.activeProductsChartData; // Active Products
        case 5: return data.ratingChartData;
        default: return data.productsChartData;
      }
    }

    String getMetricTitle() {
      switch (_selectedProductMetricIndex) {
        case 0: return 'Products';
        case 1: return 'Revenue';
        case 2: return 'Sold';
        case 3: return 'Average Price';
        case 4: return 'Active Products';
        case 5: return 'Rating';
        default: return 'Products';
      }
    }

    final spots = getSelectedMetricData();
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getMetricTitle(),
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: spots.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No data available for selected period',
                        style: GoogleFonts.dmSans(
                          fontSize: 14, 
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1.0,
                    minY: 0,
                    maxY: spots.isNotEmpty ? spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.1 : 100.0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.green,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter
                          )
                        )
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(ProductPerformanceData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Products by Revenue', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (data.topProducts.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No products sold in this period',
                    style: GoogleFonts.dmSans(
                      fontSize: 14, 
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...data.topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: product['image'] != null && product['image'].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product['image'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(Icons.inventory_2, color: Colors.grey[600]),
                            ),
                          )
                        : Icon(Icons.inventory_2, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${product['name']}',
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RM${product['revenue'].toStringAsFixed(2)} • ${product['sold']} sold',
                            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isUp;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isUp,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey[200]!),
           boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 10,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis,),
            Flexible(
              child: Container(), // Flexible spacer instead of Spacer
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: isUp ? Colors.green : Colors.red),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(change, style: GoogleFonts.dmSans(fontSize: 10, color: isUp ? Colors.green : Colors.red), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceDataItem extends StatelessWidget {
    final String value;
    final String label;
    final String description;

    const _PerformanceDataItem({required this.value, required this.label, required this.description});

    @override
    Widget build(BuildContext context) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                        Text(value, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                        Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey[600])),
                    ],
                ),
                const SizedBox(height: 4),
                Text(description, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[700])),
            ],
        );
    }
}