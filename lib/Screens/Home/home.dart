import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:glassmorphism_widgets/glassmorphism_widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sangeet/CustomWidgets/custom_physics.dart';
import 'package:sangeet/CustomWidgets/gradient_containers.dart';
import 'package:sangeet/CustomWidgets/miniplayer.dart';
import 'package:sangeet/CustomWidgets/snackbar.dart';
import 'package:sangeet/Helpers/backup_restore.dart';
import 'package:sangeet/Helpers/downloads_checker.dart';
import 'package:sangeet/Helpers/github.dart';
import 'package:sangeet/Screens/Home/saavn.dart';
import 'package:sangeet/Screens/Library/library.dart';
import 'package:sangeet/Screens/LocalMusic/downed_songs.dart';
import 'package:sangeet/Screens/Search/search.dart';
import 'package:sangeet/Screens/Settings/setting.dart';
import 'package:sangeet/Screens/Top%20Songs/top.dart';
import 'package:sangeet/Screens/YouTube/youtube_home.dart';
import 'package:sangeet/Services/ext_storage_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  bool checked = false;
  String? appVersion;
  bool checkUpdate =
      Hive.box('settings').get('checkUpdate', defaultValue: false) as bool;
  bool autoBackup =
      Hive.box('settings').get('autoBackup', defaultValue: false) as bool;
  List sectionsToShow = Hive.box('settings').get(
    'sectionsToShow',
    defaultValue: ['Home', 'Top Songs', 'YouTube', 'Library'],
  ) as List;
  DateTime? backButtonPressTime;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  void callback() {
    sectionsToShow = Hive.box('settings').get(
      'sectionsToShow',
      defaultValue: ['Home', 'Top Songs', 'YouTube', 'Library'],
    ) as List;
    setState(() {});
  }

  void _onItemTapped(int index) {
    _selectedIndex.value = index;
    _pageController.jumpToPage(index);
  }

  bool compareVersion(String latestVersion, String currentVersion) {
    bool update = false;
    final List latestList = latestVersion.split('.');
    final List currentList = currentVersion.split('.');
    for (int i = 0; i < latestList.length; i++) {
      try {
        if (int.parse(latestList[i] as String) >
            int.parse(currentList[i] as String)) {
          update = true;
          break;
        }
      } catch (e) {
        Logger.root.severe('Error while comparing versions: $e');
        break;
      }
    }
    return update;
  }

  Future<bool> handleWillPop(BuildContext context) async {
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
        backButtonPressTime == null ||
            now.difference(backButtonPressTime!) > const Duration(seconds: 3);
    if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
      backButtonPressTime = now;
      ShowSnackBar().showSnackBar(
        context,
        AppLocalizations.of(context)!.exitConfirm,
        duration: const Duration(seconds: 2),
        noAction: true,
      );
      return false;
    }
    return true;
  }

  Widget checkVersion() {
    if (!checked) {
      checked = true;
      PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
        appVersion = packageInfo.version;
        if (checkUpdate) {
          GitHub.getLatestVersion().then((String version) async {
            if (compareVersion(version, appVersion!)) {
              ShowSnackBar().showSnackBar(
                context,
                AppLocalizations.of(context)!.updateAvailable,
                duration: const Duration(seconds: 15),
                action: SnackBarAction(
                  textColor: Theme.of(context).colorScheme.secondary,
                  label: AppLocalizations.of(context)!.update,
                  onPressed: () {
                    Navigator.pop(context);
                    launchUrl(
                      Uri.parse('https://sumanishere.github.io/Sangeet/'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              );
            }
          });
        }
        if (autoBackup) {
          final List<String> checked = [
            AppLocalizations.of(context)!.settings,
            AppLocalizations.of(context)!.downs,
            AppLocalizations.of(context)!.playlists,
          ];
          final List playlistNames = Hive.box('settings')
              .get('playlistNames', defaultValue: ['Favorite Songs']) as List;
          final Map<String, List> boxNames = {
            AppLocalizations.of(context)!.settings: ['settings'],
            AppLocalizations.of(context)!.cache: ['cache'],
            AppLocalizations.of(context)!.downs: ['downloads'],
            AppLocalizations.of(context)!.playlists: playlistNames,
          };
          final String autoBackPath = Hive.box('settings')
              .get('autoBackPath', defaultValue: '') as String;
          if (autoBackPath == '') {
            ExtStorageProvider.getExtStorage(
              dirName: 'Sangeet/Backups',
              writeAccess: true,
            ).then((value) {
              Hive.box('settings').put('autoBackPath', value);
              createBackup(
                context,
                checked,
                boxNames,
                path: value,
                fileName: 'Sangeet_AutoBackup',
                showDialog: false,
              );
            });
          } else {
            createBackup(
              context,
              checked,
              boxNames,
              path: autoBackPath,
              fileName: 'Sangeet_AutoBackup',
              showDialog: false,
            );
          }
        }
      });
      if (Hive.box('settings').get('proxyIp') == null) {
        Hive.box('settings').put('proxyIp', '103.47.67.134');
      }
      if (Hive.box('settings').get('proxyPort') == null) {
        Hive.box('settings').put('proxyPort', 8080);
      }
      downloadChecker();
      return const SizedBox();
    } else {
      return const SizedBox();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool rotated = MediaQuery.of(context).size.height < screenWidth;
    return GradientContainer(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        drawer: Drawer(
          child: GradientContainer(
            child: CustomScrollView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  stretch: true,
                  expandedHeight: MediaQuery.of(context).size.height * 0.2,
                  flexibleSpace: FlexibleSpaceBar(
                    title: RichText(
                      text: TextSpan(
                        text: AppLocalizations.of(context)!.appTitle,
                        style: const TextStyle(
                          fontSize: 30.0,
                          fontWeight: FontWeight.w500,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: appVersion == null ? '' : '\nv$appVersion',
                            style: const TextStyle(fontSize: 7.0),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.end,
                    ),
                    titlePadding: const EdgeInsets.only(bottom: 40.0),
                    centerTitle: true,
                    background: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.1),
                          ],
                        ).createShader(
                          Rect.fromLTRB(0, 0, rect.width, rect.height),
                        );
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image(
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        image: AssetImage(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'assets/header-dark.jpg'
                              : 'assets/header.jpg',
                        ),
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      ListTile(
                        title: Text(
                          AppLocalizations.of(context)!.home,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          Icons.home_rounded,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        selected: true,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      if (Platform.isAndroid)
                        ListTile(
                          title: Text(AppLocalizations.of(context)!.myMusic),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20.0),
                          leading: Icon(
                            MdiIcons.folderMusic,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DownloadedSongs(
                                  showPlaylists: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.downs),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          Icons.download_done_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/downloads');
                        },
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.playlists),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          Icons.playlist_play_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/playlists');
                        },
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.settings),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          Icons.settings_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SettingPage(callback: callback),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.about),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                        leading: Icon(
                          Icons.info_outline_rounded,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/about');
                        },
                      ),
                    ],
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: <Widget>[
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(5, 30, 5, 20),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.madeBy,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: WillPopScope(
          onWillPop: () => handleWillPop(context),
          child: SafeArea(
            child: Row(
              children: [
                if (rotated)
                  ValueListenableBuilder(
                    valueListenable: _selectedIndex,
                    builder:
                        (BuildContext context, int indexValue, Widget? child) {
                      return NavigationRail(
                        minWidth: 70.0,
                        groupAlignment: 0.0,
                        backgroundColor: Theme.of(context).cardColor,
                        selectedIndex: indexValue,
                        onDestinationSelected: (int index) {
                          _onItemTapped(index);
                        },
                        labelType: screenWidth > 1050
                            ? NavigationRailLabelType.selected
                            : NavigationRailLabelType.none,
                        selectedLabelTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelTextStyle:
                            TextStyle(color: Theme.of(context).iconTheme.color),
                        selectedIconTheme: Theme.of(context).iconTheme.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                        unselectedIconTheme: Theme.of(context).iconTheme,
                        useIndicator: screenWidth < 1050,
                        indicatorColor: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.2),
                        leading: screenWidth > 1050
                            ? null
                            : Builder(
                                builder: (context) => Transform.rotate(
                                  angle: 22 / 7 * 2,
                                  child: IconButton(
                                    icon: const Icon(Icons.table_rows_rounded),
                                    onPressed: () {
                                      Scaffold.of(context).openDrawer();
                                    },
                                    tooltip: MaterialLocalizations.of(context)
                                        .openAppDrawerTooltip,
                                  ),
                                ),
                              ),
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.home_rounded),
                            label: Text(AppLocalizations.of(context)!.home),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.trending_up_rounded),
                            label:
                                Text(AppLocalizations.of(context)!.topCharts),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(MdiIcons.youtube),
                            label: Text(AppLocalizations.of(context)!.youTube),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.my_library_music_rounded),
                            label: Text(AppLocalizations.of(context)!.library),
                          ),
                        ],
                      );
                    },
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          physics: const CustomPhysics(),
                          onPageChanged: (indx) => _selectedIndex.value = indx,
                          controller: _pageController,
                          children: [
                            Stack(
                              children: [
                                checkVersion(),
                                NestedScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  controller: _scrollController,
                                  headerSliverBuilder: (
                                    BuildContext context,
                                    bool innerBoxScrolled,
                                  ) {
                                    return <Widget>[
                                      SliverAppBar(
                                        expandedHeight: 135,
                                        backgroundColor: Colors.transparent,
                                        elevation: 0,
                                        toolbarHeight: 65,
                                        automaticallyImplyLeading: false,
                                        flexibleSpace: LayoutBuilder(
                                          builder: (
                                            BuildContext context,
                                            BoxConstraints constraints,
                                          ) {
                                            return FlexibleSpaceBar(
                                              background: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  const SizedBox(height: 60),
                                                  Row(
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          left: 15.0,
                                                        ),
                                                        child: Text(
                                                          AppLocalizations.of(
                                                            context,
                                                          )!
                                                              .discover,
                                                          style: TextStyle(
                                                            letterSpacing: 3,
                                                            color: Theme.of(
                                                              context,
                                                            )
                                                                .colorScheme
                                                                .secondary,
                                                            fontSize: 50,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left: 15.0,
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            AppLocalizations.of(
                                                              context,
                                                            )!
                                                                .recommended,
                                                            style:
                                                                const TextStyle(
                                                              letterSpacing: 2,
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ];
                                  },
                                  body: SaavnHomePage(),
                                ),
                                if (!rotated || screenWidth > 1050)
                                  Builder(
                                    builder: (context) => Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8.0,
                                        left: 4.0,
                                      ),
                                      child: Transform.rotate(
                                        angle: 22 / 7 * 2,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.table_rows_rounded,
                                          ),
                                          onPressed: () {
                                            Scaffold.of(context).openDrawer();
                                          },
                                          tooltip:
                                              MaterialLocalizations.of(context)
                                                  .openAppDrawerTooltip,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (sectionsToShow.contains('Top Songs'))
                              TopCharts(pageController: _pageController),
                            const YouTube(),
                            const LibraryPage(),
                            if (sectionsToShow.contains('Settings'))
                              SettingPage(callback: callback),
                          ],
                        ),
                      ),
                      MiniPlayer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: rotated
            ? null
            : Padding(
                padding: EdgeInsets.zero, // Remove padding from SafeArea
                child: SafeArea(
                  child: ValueListenableBuilder(
                    valueListenable: _selectedIndex,
                    builder:
                        (BuildContext context, int indexValue, Widget? child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        height: 60,
                        child: GlassFlexContainer(
                          borderRadius: BorderRadius.zero,
                          borderGradient: const LinearGradient(
                            colors: [Color.fromARGB(0, 11, 11, 11)],
                            stops: [0],
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: BottomNavigationBar(
                              type: BottomNavigationBarType.fixed,
                              currentIndex: indexValue,
                              onTap: _onItemTapped,
                              items: [
                                BottomNavigationBarItem(
                                  icon: const Icon(
                                    Icons.home_filled,
                                    size: 35,
                                  ),
                                  label: AppLocalizations.of(context)!.home,
                                ),
                                if (sectionsToShow.contains('Top Songs'))
                                  BottomNavigationBarItem(
                                    icon: const Icon(
                                      Icons.travel_explore_rounded,
                                      size: 35,
                                    ),
                                    label:
                                        AppLocalizations.of(context)!.topCharts,
                                  ),
                                BottomNavigationBarItem(
                                  icon: const Icon(
                                    MdiIcons.youtube,
                                    size: 35,
                                  ),
                                  label: AppLocalizations.of(context)!.youTube,
                                ),
                                BottomNavigationBarItem(
                                  icon: const Icon(
                                    Icons.my_library_music_rounded,
                                    size: 35,
                                  ),
                                  label: AppLocalizations.of(context)!.library,
                                ),
                                if (sectionsToShow.contains('Settings'))
                                  BottomNavigationBarItem(
                                    icon: const Icon(
                                      Icons.settings_rounded,
                                      size: 35,
                                    ),
                                    label:
                                        AppLocalizations.of(context)!.settings,
                                  ),
                              ],
                              elevation: 0,
                              selectedLabelStyle:
                                  const TextStyle(color: Colors.white),
                              selectedItemColor:
                                  const Color.fromARGB(255, 255, 17, 0),
                              unselectedItemColor: Colors.grey,
                              showUnselectedLabels: true,
                              backgroundColor: Colors.transparent,
                              unselectedFontSize: 13.0,
                              selectedFontSize: 13.0,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
