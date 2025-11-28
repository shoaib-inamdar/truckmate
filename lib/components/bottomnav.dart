import 'package:flutter/material.dart';

class Bottomnav extends StatelessWidget {
  const Bottomnav({super.key});

  @override
Widget _buildBottomNav(BuildContext context, int currentIndex) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, -5),
        ),
      ],
    ),
    child: BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF7C4DFF),
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      elevation: 0,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'Favourites',
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}