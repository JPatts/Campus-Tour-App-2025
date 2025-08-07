import 'package:campus_tour/models/hotspot.dart';
import 'package:flutter/material.dart';
// ignore: unused_import
import 'services/hotspot_service.dart';


List<Hotspot> children = myService.getHostpots();
class LocationList extends StatefulWidget{
  const LocationList({Key? key}) : super(key: key);

  // void mmm(){
  //   debugPrint(children[0].name);
  // }

  @override
  State<LocationList> createState() => _LocationList();
}

class _LocationList extends State<LocationList>{

  void update() async{
    setState((){});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Locations"),
        backgroundColor: const Color.fromARGB(255, 52, 209, 94),
        centerTitle: true,
      ),
      body: ListView.separated(
        separatorBuilder: (context, index) => Divider(color: Colors.grey), 
        itemCount: children.length,
        //List<Widget> children = const <Widget>[]
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(children[index].name),
            subtitle: Text(children[index].description)
          ); 
        }),
    );
  }
}