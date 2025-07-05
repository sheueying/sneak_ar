// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'services/snapchat_ar_service.dart';
// import 'home_screen.dart';
// import 'favourite_screen.dart';
// import 'cart_screen.dart';
// import 'user_profile_screen.dart';
// import 'widgets/bottom_nav_bar.dart';

// class ARCamScreen extends StatefulWidget {
//   const ARCamScreen({super.key});

//   @override
//   State<ARCamScreen> createState() => _ARCamScreenState();
// }

// class _ARCamScreenState extends State<ARCamScreen> {
//   String? _selectedShoeId;
//   String? _selectedShoeName;
//   bool _isLoading = false;

//   void _selectShoe(String shoeId) {
//     final shoeInfo = SnapchatARService.getShoeInfo(shoeId);
//     if (shoeInfo != null) {
//       setState(() {
//         _selectedShoeId = shoeId;
//         _selectedShoeName = shoeInfo['name'] as String;
//       });
//     }
//   }

//   void _launchAR() async {
//     if (_selectedShoeId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select a shoe first'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       // Save AR session to Firestore
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         try {
//           await FirebaseFirestore.instance.collection('ar_sessions').add({
//             'userId': user.uid,
//             'shoeId': _selectedShoeId,
//             'startTime': DateTime.now().toIso8601String(),
//             'platform': 'snapchat',
//           });
//         } catch (e) {
//           // Ignore Firestore errors for now
//           if (kDebugMode) {
//             print('Firestore error (ignored): $e');
//           }
//         }
//       }

//       // Launch Snapchat AR using the service
//       final success = await SnapchatARService.launchShoeTryOn(_selectedShoeId!);
      
//       if (success) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Opening Snapchat AR...'),
//               duration: Duration(seconds: 2),
//             ),
//           );
//         }
//       } else {
//         // If specific AR filter failed, try to open Snapchat camera
//         final cameraSuccess = await SnapchatARService.launchSnapchatCamera();
//         if (cameraSuccess) {
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text('Opened Snapchat! Use the camera to try AR filters.'),
//                 duration: Duration(seconds: 3),
//               ),
//             );
//           }
//         } else {
//           if (mounted) {
//             _showSnapchatNotAvailableDialog();
//           }
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('AR launch error: $e');
//       }
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('An error occurred. Please try again.'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   void _showSnapchatNotAvailableDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Snapchat Not Available'),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Snapchat couldn\'t be opened. You can:'),
//             SizedBox(height: 10),
//             Text('• Install Snapchat from the Play Store'),
//             Text('• Try the AR feature later'),
//             Text('• Use the camera to take photos of the shoes'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _installSnapchat();
//             },
//             child: const Text('Install Snapchat'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // Camera background (placeholder)
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [
//                   Color(0xFF1a1a1a),
//                   Color(0xFF2d2d2d),
//                 ],
//               ),
//             ),
//           ),
          
//           // AR overlay with instructions
//           _buildAROverlay(),
          
//           // UI controls
//           _buildControls(),
          
//           // Shoe selection
//           _buildShoeSelection(),
          
//           // Loading overlay
//           if (_isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.7),
//               child: const Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircularProgressIndicator(color: Colors.white),
//                     SizedBox(height: 20),
//                     Text(
//                       'Opening Snapchat AR...',
//                       style: TextStyle(color: Colors.white, fontSize: 18),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//       bottomNavigationBar: BottomNavBar(
//         currentIndex: 2, // AR tab index
//         onTap: (index) {
//           if (index == 0) {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (context) => const HomeScreen()),
//             );
//           } else if (index == 1) {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (context) => const FavouriteScreen()),
//             );
//           } else if (index == 3) {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (context) => const CartScreen()),
//             );
//           } else if (index == 4) {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (context) => const UserProfileScreen()),
//             );
//           }
//           // index == 2 is current AR screen, do nothing
//         },
//       ),
//     );
//   }

//   Widget _buildAROverlay() {
//     return Positioned.fill(
//       child: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Colors.transparent,
//               Colors.black.withOpacity(0.3),
//             ],
//           ),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // AR instructions
//             Container(
//               margin: const EdgeInsets.all(20),
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.8),
//                 borderRadius: BorderRadius.circular(15),
//               ),
//               child: Column(
//                 children: [
//                   const Icon(
//                     Icons.view_in_ar,
//                     color: Colors.white,
//                     size: 48,
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     _selectedShoeId != null 
//                       ? 'Ready to try on $_selectedShoeName!'
//                       : 'Select a shoe to try on',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 8),
//                   const Text(
//                     'Tap the AR button to launch Snapchat and try on your selected shoe with AR technology.',
//                     style: TextStyle(
//                       color: Colors.white70,
//                       fontSize: 14,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildControls() {
//     return Positioned(
//       bottom: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         padding: const EdgeInsets.all(20),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Colors.transparent,
//               Colors.black.withOpacity(0.7),
//             ],
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             // AR button
//             FloatingActionButton.large(
//               heroTag: "ar_button",
//               onPressed: _isLoading ? null : _launchAR,
//               backgroundColor: Colors.yellow,
//               child: const Icon(
//                 Icons.view_in_ar,
//                 color: Colors.black,
//                 size: 32,
//               ),
//             ),
            
//             // Settings button
//             FloatingActionButton(
//               heroTag: "settings_button",
//               onPressed: _showSettings,
//               backgroundColor: Colors.grey,
//               child: const Icon(Icons.settings),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildShoeSelection() {
//     final shoes = SnapchatARService.availableShoes;
    
//     return Positioned(
//       top: 100,
//       left: 0,
//       right: 0,
//       child: Container(
//         height: 120,
//         padding: const EdgeInsets.symmetric(horizontal: 20),
//         child: ListView.builder(
//           scrollDirection: Axis.horizontal,
//           itemCount: shoes.length,
//           itemBuilder: (context, index) {
//             final shoe = shoes[index];
//             final isSelected = _selectedShoeId == shoe['id'];
            
//             return GestureDetector(
//               onTap: () => _selectShoe(shoe['id']),
//               child: Container(
//                 width: 100,
//                 margin: const EdgeInsets.only(right: 15),
//                 decoration: BoxDecoration(
//                   color: isSelected ? Colors.yellow : Colors.white,
//                   borderRadius: BorderRadius.circular(10),
//                   border: Border.all(
//                     color: isSelected ? Colors.yellow : Colors.grey,
//                     width: 2,
//                   ),
//                 ),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Image.asset(
//                       shoe['image'],
//                       width: 50,
//                       height: 50,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Container(
//                           width: 50,
//                           height: 50,
//                           color: Colors.grey,
//                           child: const Icon(Icons.sports_soccer, color: Colors.white),
//                         );
//                       },
//                     ),
//                     const SizedBox(height: 5),
//                     Text(
//                       shoe['name'],
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: isSelected ? Colors.black : Colors.black,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   void _showSettings() {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => Container(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               'AR Settings',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             ListTile(
//               title: const Text('Install Snapchat'),
//               leading: const Icon(Icons.download),
//               onTap: () {
//                 Navigator.pop(context);
//                 _installSnapchat();
//               },
//             ),
//             ListTile(
//               title: const Text('AR History'),
//               leading: const Icon(Icons.history),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showARHistory();
//               },
//             ),
//             ListTile(
//               title: const Text('Help'),
//               leading: const Icon(Icons.help),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showHelp();
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _installSnapchat() async {
//     const url = 'https://play.google.com/store/apps/details?id=com.snapchat.android';
//     if (await canLaunchUrl(Uri.parse(url))) {
//       await launchUrl(Uri.parse(url));
//     }
//   }

//   void _showARHistory() {
//     // TODO: Implement AR history screen
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('AR History coming soon!')),
//     );
//   }

//   void _showHelp() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('AR Try-On Help'),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('1. Select a shoe from the top list'),
//             Text('2. Tap the AR button to launch Snapchat'),
//             Text('3. Use Snapchat\'s AR filters to try on the shoe'),
//             Text('4. Take photos and share with friends'),
//             SizedBox(height: 10),
//             Text('Note: Snapchat must be installed for AR try-on.'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }
// } 