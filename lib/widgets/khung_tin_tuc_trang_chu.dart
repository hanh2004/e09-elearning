import 'dart:async';

import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';
import '../models/anh_bia_trang_chu.dart';
import '../services/nghiep_vu/dich_vu_tin_tuc.dart';
import '../services/nghiep_vu/dich_vu_anh_bia_trang_chu.dart';
import '../screens/user/chi_tiet_tin_tuc.dart';
import 'anh_bia_khoa_hoc.dart';
import 'thong_bao_loi.dart';

class HomeNewsBanner extends StatefulWidget {
  const HomeNewsBanner({
    super.key,
    required this.service,
    required this.onStudy,
  });
  final NewsService service;
  final VoidCallback onStudy;
  @override
  State<HomeNewsBanner> createState() => _TrangThaiBannerTinTuc();
}

class _TrangThaiBannerTinTuc extends State<HomeNewsBanner> {
  late final homeBanners = HomeBannerService(widget.service.db);
  final controller = PageController();
  Timer? autoplay;
  int selected = 0;
  int bannerCount = -1;

  void configureAutoplay(int soLuong) {
    if (bannerCount == soLuong) return;
    bannerCount = soLuong;
    autoplay?.cancel();
    selected = soLuong == 0 ? 0 : selected.clamp(0, soLuong - 1);
    if (soLuong > 1) {
      autoplay = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !controller.hasClients) return;
        final tiepTheo = (selected + 1) % soLuong;
        controller.animateToPage(
          tiepTheo,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    autoplay?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ReloadableStreamBuilder<List<HomeBanner>>(
        streamFactory: _bannerTinTuc,
        feature: 'Tải tin nổi bật trang chủ',
        builder: (context, duLieuNhan) {
          if (!duLieuNhan.hasData) return const LinearProgressIndicator();
          final cacAnhNoiBat = duLieuNhan.data ?? <HomeBanner>[];
          if (cacAnhNoiBat.isNotEmpty) return _bangAnhTruot(cacAnhNoiBat);
          return ReloadableStreamBuilder<List<HomeBanner>>(
            streamFactory: homeBanners.active,
            feature: 'Tải ảnh bìa trang chủ',
            builder: (context, configuredSnapshot) {
              if (!configuredSnapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final configured = configuredSnapshot.data ?? <HomeBanner>[];
              if (configured.isNotEmpty) return _bangAnhTruot(configured);
              configureAutoplay(0);
              return _duPhong();
            },
          );
        },
      );

  Stream<List<HomeBanner>> _bannerTinTuc() => widget.service.published().map(
    (cacMuc) => cacMuc
        .where((baiViet) => baiViet.coverUrl.isNotEmpty)
        .take(5)
        .map(
          (baiViet) => HomeBanner(baiViet.id, {
            'imageUrl': baiViet.coverUrl,
            'title': baiViet.title,
            'order': 0,
            'newsId': baiViet.id,
          }),
        )
        .toList(),
  );

  Widget _duPhong() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF1BD), Color(0xFFFFF9E9), Color(0xFFF5D77D)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HỌC TẬP SỐ E09',
          style: TextStyle(
            color: AppTheme.red,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Bồi dưỡng kiến thức.\nVững vàng nghiệp vụ.',
          style: TextStyle(
            color: AppTheme.red,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: widget.onStudy,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Khám phá khóa học'),
        ),
      ],
    ),
  );

  Widget _bangAnhTruot(List<HomeBanner> cacAnhNoiBat) {
    configureAutoplay(cacAnhNoiBat.length);
    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            key: ValueKey(cacAnhNoiBat.map((a) => a.id).join(',')),
            controller: controller,
            itemCount: cacAnhNoiBat.length,
            onPageChanged: (giaTri) => setState(() => selected = giaTri),
            itemBuilder: (context, viTri) {
              final anhNoiBat = cacAnhNoiBat[viTri];
              return Semantics(
                label: 'Banner ${viTri + 1}: ${anhNoiBat.title}',
                button: true,
                child: InkWell(
                  onTap: () {
                    if (anhNoiBat.newsId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => NewsDetailScreen(
                            id: anhNoiBat.newsId!,
                            service: widget.service,
                          ),
                        ),
                      );
                    } else {
                      widget.onStudy();
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CourseCover(
                          brandFallback: true,
                          url: anhNoiBat.imageUrl,
                          width: double.infinity,
                          height: 230,
                        ),
                        if (anhNoiBat.title.isNotEmpty)
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xDD000000)],
                              ),
                            ),
                          ),
                        if (anhNoiBat.title.isNotEmpty)
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 20,
                            child: Text(
                              anhNoiBat.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (cacAnhNoiBat.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var viTri = 0; viTri < cacAnhNoiBat.length; viTri++)
                IconButton(
                  tooltip: 'Banner ${viTri + 1}',
                  iconSize: 10,
                  color: selected.clamp(0, cacAnhNoiBat.length - 1) == viTri
                      ? AppTheme.red
                      : Colors.grey.shade300,
                  onPressed: () => controller.animateToPage(
                    viTri,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                  icon: const Icon(Icons.circle),
                ),
            ],
          ),
      ],
    );
  }
}
