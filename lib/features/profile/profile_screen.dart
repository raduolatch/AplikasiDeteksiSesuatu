import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader(title: 'Profil'),
          // TODO: isi profil (foto, nama, riwayat deteksi, tentang aplikasi)
        ],
      ),
    );
  }
}