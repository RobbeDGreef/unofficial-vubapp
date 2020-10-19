import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import "package:intl/intl.dart";
import "package:flushbar/flushbar.dart";

import "calendar_strip/calendar_strip.dart";
import "mapview.dart";
import "parser.dart";
import "infohandler.dart";
import "settings.dart";
import "const.dart";
import "places.dart";
import 'coursesview.dart';
import 'help.dart';
import 'theming.dart';

void main() => runApp(Vub());

/// The main app
class Vub extends StatelessWidget {
  final theme = ThemeData(primaryColor: Color.fromARGB(0xFF, 0, 52, 154));
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: "VUB class schedules", home: MainUi());
  }
}

/// Statefull widget used to store all immutable data
/// so that we can change state using the State widget
class MainUi extends StatefulWidget {
  InfoHandler infoHandler;

  MainUi() {
    infoHandler = InfoHandler();
  }

  @override
  ClassesToday createState() {
    return ClassesToday(this.infoHandler);
  }
}

/// The state object, this object will be regenerated and
/// the data is thus mutable.
class ClassesToday extends State<MainUi> {
  InfoHandler _info;
  List<Lecture> _classes = [];
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedWeek = DateTime.now();
  int _todaysColor = 0;
  int _selectedNavBarIndex = 0;
  bool _loading = true;

  ClassesToday(InfoHandler info) {
    this._info = info;
    loadNewClassData(DateTime.now(), false);
  }

  /// This function will update the this._classes list
  /// it takes an extra optional flag for handling the loading
  void loadNewClassData(DateTime date, [bool shouldSetState = true]) {
    if (shouldSetState) {
      setState(() {
        this._loading = true;
        this._classes.clear();
      });
    }

    this._info.getClassesOfDay(date).then((list) {
      this._loading = false;
      update(list);
    });
  }

  /// This function will update the this._classes list from
  /// a parsed Lecture object data list. It handles sorting
  /// and other hacks.
  void update(List<Lecture> classes) {
    print("Updating");
    setState(() {
      bool rotset = false;
      this._classes.clear();

      for (Lecture lec in classes) {
        // If the rotationsystem is already specified don't add it again
        if (lec.name.toLowerCase().contains("rotatie")) {
          if (rotset) continue;
          rotset = true;
        }

        int i = 0;
        for (Lecture prevLec in this._classes) {
          if (lec.start.compareTo(prevLec.start) < 0) {
            this._classes.insert(i, lec);
            break;
          }
          ++i;
        }
        if (this._classes.length == i) {
          this._classes.add(lec);
        }
      }
    });
  }

  DateTime _calcWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Widget _buildMonthNameWidget(String monthString) {
    /// What we would like to achieve:
    ///   Month1 / Month2 2020            week x
    ///
    /// note that month2 is optional (for weeks that start in a different
    /// month than they end)

    /*
    DateTime weekStart = _calcWeekStart(date);
    DateTime weekEnd = _calcWeekStart(date).add(Duration(days: 6));

    String monthString = DateFormat("MMMM").format(weekStart);
    if (weekStart.month != weekEnd.month) {
      monthString += " / " + DateFormat("MMMM").format(weekEnd);
    }
    */

    int weekNum = this._info.calcWeekFromDate(this._selectedWeek);
    String weekString = "week $weekNum";

    // We want to prevent printing week 0 or week -1 etc
    if (weekNum > 0) {
      monthString += " - " + weekString;
    }

    TextStyle style = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87);
    return Padding(
      padding: EdgeInsets.only(top: 7, bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(monthString, style: style),
        ],
      ),
    );
  }

  Widget _buildWeekScroller() {
    /// I hate this. This is such a hack but the code from calendar_strip doesn't allow
    /// for selectedDate to exist without startDate and endDate being specified.
    /// to be clear, it should, but there are quite a few bugs in that code and I'm pretty
    /// sure this is one of them.

    DateTime selected = this._selectedDay != null ? this._selectedDay : DateTime.now();
    return CalendarStrip(
        monthNameWidget: _buildMonthNameWidget,
        selectedDate: selected,
        startDate: DateTime(0),
        endDate: DateTime(3000),
        addSwipeGesture: true,
        onWeekSelected: ((date) {
          this._selectedWeek = date;
        }),
        onDateSelected: ((date) {
          this._selectedDay = date;
          loadNewClassData(date);
        }));
  }

  /// Prettify the minutes string to use double digit notation
  String _prettyMinutes(int x) {
    String s = x.toString();
    if (s.length == 1) {
      s = ['0', s].join("");
    }
    return s;
  }

  List<Color> _colorFromRotString(String rotsystem) {
    rotsystem = rotsystem.toLowerCase();
    if (rotsystem.contains("blauw")) {
      return [VubBlue, Colors.white];
    } else if (rotsystem.contains("oranje")) {
      return [VubOrange, Colors.white];
    }

    return [null, null];
  }

  Widget _buildLectureDetailTile(String text, Icon icon) {
    return Card(
        margin: EdgeInsets.only(left: 8, right: 8, bottom: 4, top: 4),
        child: ListTile(
          title: Text(text),
          leading: icon,
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: text));
            Flushbar(
              margin: EdgeInsets.all(8),
              borderRadius: 8,
              message: "Copied text to clipboard",
              icon: Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
              duration: Duration(seconds: 2),
              animationDuration: Duration(milliseconds: 500),
            ).show(context);
          },
        ));
  }

  Widget _buildLectureDetails(int index) {
    Lecture lec = this._classes[index];

    // Nothing special going on here, just instead of writing the whole
    // widget tree every time for theses objects i just added them to a list
    // to cleanly generate them at the bottom of the function.
    final List<List<dynamic>> details = [
      [lec.professor, Icon(Icons.person_outline)],
      [lec.details, Icon(Icons.dehaze)],
      [lec.location, Icon(Icons.location_on)],
      [lec.remarks, Icon(Icons.event_note_outlined)],
      [
        DateFormat("EEEE d MMMM").format(lec.start) +
            " from " +
            DateFormat("H:mm").format(lec.start) +
            " until " +
            DateFormat("H:mm").format(lec.end),
        Icon(Icons.access_time)
      ]
    ];

    final List<Widget> children = [
      Padding(
          padding: EdgeInsets.only(left: 4, right: 4, bottom: 16, top: 16),
          child: Text(
            lec.name,
            style: TextStyle(fontSize: 20, color: AlmostDark),
            textAlign: TextAlign.center,
          )),
    ];

    for (List<dynamic> info in details) {
      if (info[0] != "") children.add(_buildLectureDetailTile(info[0], info[1]));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Details")),
      body: ListView(children: children),
      backgroundColor: AlmostWhite,
    );
  }

  void _openLectureDetails(int index) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) => _buildLectureDetails(index)));
  }

  /// Creates a class or lecture tab for the
  Widget _buildClassListTile(BuildContext context, int i) {
    // Display a circular throbber to show the user the system is loading
    if (this._loading) {
      return Center(
          child: Container(
        margin: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
        width: 50,
        height: 50,
      ));
    }

    // Display a widget so the user knows he has no classes and that it is
    // normal that the list view is empty.
    if (this._classes.length == 0) {
      return ListTile(title: Text("No classes today", textAlign: TextAlign.center));
    }

    var icon = Icons.record_voice_over_outlined;
    if (this._classes[i].name.toLowerCase().contains("wpo")) {
      icon = Icons.subject;
    }

    var colors = _colorFromRotString(this._classes[i].name);

    if (this._classes[i].name.toLowerCase().contains("<font color=")) {
      return Card(
          child: ListTile(
              title: Text(
                  "Rotatiesysteem: rotatie " +
                      (this._classes[i].name.contains("BLAUW") ? "blauw" : "oranje"),
                  style: TextStyle(color: colors[1]))),
          color: colors[0]);
    }

    String policyString = this._classes[i].remarks;
    if (this._classes[i].remarks.toLowerCase().contains("rotatiesysteem"))
      policyString = "Rotatiesysteem: " +
          ((this._info.isUserAllowed(this._todaysColor))
              ? "you are allowed to come"
              : "you are not allowed to come");

    return Card(
        child: ListTile(
            leading: Icon(icon),
            title: Text(this._classes[i].name),
            isThreeLine: false,
            onTap: () => _openLectureDetails(i),
            subtitle: Padding(
                padding: EdgeInsets.all(0),
                child: Column(children: [
                  Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                            child:
                                Text(this._classes[i].location, overflow: TextOverflow.ellipsis)),
                        Text(this._classes[i].start.hour.toString() +
                            ":" +
                            _prettyMinutes(this._classes[i].end.minute) +
                            " - " +
                            this._classes[i].end.hour.toString() +
                            ":" +
                            _prettyMinutes(this._classes[i].end.minute))
                      ], mainAxisAlignment: MainAxisAlignment.spaceBetween)),
                  Row(children: [
                    Expanded(child: Text(policyString, overflow: TextOverflow.ellipsis))
                  ], mainAxisAlignment: MainAxisAlignment.start)
                ]))));
  }

  /// Builds the lesson tray (the main screen actually)
  Widget _buildLecturesScreen() {
    // The ternary operator on the item count there is used to aways
    // at least return 1, so that we can call the listview builder to build
    // our "You have no classes" and loading symbol widgets.
    return Column(
      children: [
        _buildWeekScroller(),
        Expanded(
          child: ListView.builder(
            itemBuilder: _buildClassListTile,
            itemCount: this._classes.length == 0 ? 1 : this._classes.length,
          ),
        ),
      ],
    );
  }

  void _openSettings() async {
    var groups = List<String>();
    groups.addAll(this._info.getSelectedUserGroups());

    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) => SettingsMenu(this._info)));

    if (this._info.getSelectedUserGroups() != groups) {
      loadNewClassData(this._selectedDay);
    }
  }

  void _openAbout() {
    Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: Text("About us")),
        body: Column(
          children: [
            ListView(
              shrinkWrap: true,
              padding: EdgeInsets.all(8),
              children: [
                Text(
                  "About",
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                Text("Who are we", style: TextStyle(fontSize: 20)),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(WhoAreWeText, style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
            Text("Version: $CurrentAppRelease"),
          ],
        ),
      );
    }));
  }

  Widget _buildDrawer() {
    return Drawer(
        child: ListView(
      children: [
        DrawerHeader(
            decoration: BoxDecoration(
                image: DecorationImage(image: AssetImage("assets/vub-cs2.png")),
                color: Colors.white)),
        ListTile(title: Text("Settings"), onTap: _openSettings),
        ListTile(title: Text("About"), onTap: _openAbout)
      ],
    ));
  }

  void _openLibraryBooking() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) => LibraryBookingMenu(this._info),
      ),
    );
  }

  // TODO: Move place stuff in to different file
  Widget _buildPlaceTile(String title, Function() ptr) {
    return Card(
      child: ListTile(
        contentPadding: EdgeInsets.all(5),
        leading: Icon(Icons.library_books),
        title: Text(title),
        onTap: () => ptr(),
      ),
    );
  }

  List<Widget> _getPlaces() {
    return [
      _buildPlaceTile("Centrale bibliotheek VUB", _openLibraryBooking),
    ];
  }

  Widget _buildTabScreen(int index) {
    switch (index) {
      case 0:
        return _buildLecturesScreen();

      case 1:
        return CoursesView(info: this._info);

      case 2:
        return MapView();

      case 3:
        return ListView(children: _getPlaces());

      case 4:
        return HelpView();

      default:
        return Text("Something went wrong");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = BottomNavigationBar(
      currentIndex: this._selectedNavBarIndex,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      onTap: (i) {
        setState(() {
          this._selectedNavBarIndex = i;
        });
      },
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.view_agenda),
          label: "classes",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: "courses",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: "map",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.meeting_room),
          label: "places",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.help_center),
          label: "help",
        ),
      ],
    );

    final tabText = ["Today's classes", "Course information", "VUB campus map", "places", "help"];

    final refreshAction = [
      IconButton(
          icon: Icon(Icons.replay_sharp),
          onPressed: () {
            setState(() {
              this._classes.clear();
              this._loading = true;
            });
            this._info.forceCacheUpdate(this._info.calcWeekFromDate(this._selectedDay)).then((_) {
              loadNewClassData(this._selectedDay, false);
            });
          })
    ];

    return Scaffold(
        drawer: _buildDrawer(),
        bottomNavigationBar: bottom,
        backgroundColor: AlmostWhite,
        appBar: AppBar(
            title: Text(tabText[this._selectedNavBarIndex]),
            actions: (this._selectedNavBarIndex == 0) ? refreshAction : []),
        body: _buildTabScreen(this._selectedNavBarIndex));
  }
}
