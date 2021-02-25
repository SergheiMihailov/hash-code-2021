import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:tuple/tuple.dart';

class Street {
  int id;
  int start;
  int end;
  String name;
  int length;

  List<Car> nonQueuedCars = [];
  Queue<Car> queue = Queue();

  Street({
    this.id,
    this.start,
    this.end,
    this.name,
    this.length,
  });

  void produceQueuedCar(Car car) {
    queue.addLast(car);
  }

  void addCar(Car car) {
    nonQueuedCars.add(car);
  }

  Car consumeQueuedCar() {
    return queue.removeFirst();
  }

  void driveNonQueuedCars() {
    for (var i = nonQueuedCars.length - 1; i >= 0; i--) {
      if (nonQueuedCars[i].timeOnRoad == length) {
        final car = nonQueuedCars.removeAt(i);

        produceQueuedCar(car);
      } else {
        nonQueuedCars[i].timeOnRoad++;
      }
    }
  }
}

class Car {
  int id;
  int nStreets;

  Queue<String> nextStreets = Queue();

  int timeOnRoad = 0;

  Car({
    this.id,
    this.nStreets,
  });

  void addStreet(String street) {
    nextStreets.addLast(street);
  }

  String nextStreet() {
    return nextStreets.removeFirst();
  }
}

// the individual in the population
class Intersection {
  int id;

  List<Tuple2<String, int>> incommingStreets = [];

  Intersection({
    this.id,
  });

  void addStreet(Street street, int greenLightDuration) {
    incommingStreets.add(Tuple2<String, int>(street.name, greenLightDuration));
  }

  int totalGreenDuration() {
    return incommingStreets.fold(0, (total, e) => total + e.item2);
  }

  String nextGreenStreetName(int timeElaped) {
    var interalRemainder = timeElaped % totalGreenDuration();

    Tuple2<String, int> currentIncommingStreet;

    for (var incommingStreet in incommingStreets) {
      currentIncommingStreet = incommingStreet;

      interalRemainder -= incommingStreet.item2;

      if (interalRemainder <= 0) {
        break;
      }
    }

    return currentIncommingStreet.item1;
  }
}

int simulationDuration;
int nIntersections;
int nStreets;
int nCars;
int baseCarScore;

Map<String, Street> streets = {};
List<Car> cars = [];
Map<int, Intersection> intersections = {};

final random = Random();

Future main(List<String> arguments) async {
  if (arguments.length < 2) {
    throw Exception('Invalid amount of arguments.');
  }

  final inputFilePath = arguments[0];
  final outputFilePath = arguments[1];

  await parseInput(inputFilePath);

  runSolution();

  await printOutput(outputFilePath);

  calculateAndPrintScore();
}

Future parseInput(String inputFilePath) async {
  var lineIndex = 0;

  final inputLines = File(inputFilePath)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (String line in inputLines) {
    var lineItems = line.split(' ');

    if (lineIndex == 0) {
      simulationDuration = int.parse(lineItems[0]);
      nIntersections = int.parse(lineItems[1]);
      nStreets = int.parse(lineItems[2]);
      nCars = int.parse(lineItems[3]);
      baseCarScore = int.parse(lineItems[4]);
    } else if (lineIndex <= nStreets) {
      // parse streets
      final streetName = lineItems[2];
      final end = int.parse(lineItems[1]);

      streets[streetName] = Street(
        id: lineIndex - 1,
        start: int.parse(lineItems[0]),
        end: end,
        name: streetName,
        length: int.parse(lineItems[3]),
      );

      // XXX: might be duplicate, don't care
      intersections[end] = Intersection(
        id: end,
      );
    } else {
      // parse cars
      final car = Car(
        id: lineIndex - nStreets - 1,
        nStreets: int.parse(lineItems[0]),
      );

      // add car to initial street
      streets[lineItems[1]].produceQueuedCar(car);

      // parse route
      for (var i = 2; i < lineItems.length; i++) {
        car.addStreet(lineItems[i]);
      }
    }

    lineIndex++;
  }
}

void runSolution() {
  // random initialisation
  for (final street in streets.values) {
    if (random.nextBool()) {
      intersections[street.end]
          .addStreet(street, random.nextInt(simulationDuration - 1) + 1);
    }
  }
}

Future printOutput(String outputFilePath) async {
  final outputSink = File(outputFilePath).openWrite();

  var nIntersection = 0;

  for (final intersection in intersections.values) {
    final length = intersection.incommingStreets.length;

    if (length > 0) {
      nIntersection++;
    }
  }

  await outputSink.writeln(nIntersection);

  for (final intersection in intersections.values) {
    final length = intersection.incommingStreets.length;

    if (length > 0) {
      await outputSink.writeln(intersection.id);
      await outputSink.writeln(length);

      for (var i = 0; i < length; i++) {
        final name = intersection.incommingStreets[i].item1;
        final duration = intersection.incommingStreets[i].item2;

        await outputSink.writeln('$name $duration');
      }
    }
  }

  await outputSink.close();
}

int processTick(int timeElaped) {
  var scoreThisTick = 0;

  // for each schedule get the next green light
  for (final intersection in intersections.values) {
    if (intersection.incommingStreets.isEmpty) {
      continue;
    }

    for (var i = 0; i < intersection.incommingStreets.length; i++) {
      streets[intersection.incommingStreets[i].item1].driveNonQueuedCars();
    }

    final greenStreetName = intersection.nextGreenStreetName(timeElaped);
    final greenStreet = streets[greenStreetName];

    if (greenStreet.queue.isEmpty) {
      continue;
    }

    final processedCar = greenStreet.consumeQueuedCar();

    final nextStreetName = processedCar.nextStreet();

    // check if the car is done
    if (processedCar.nextStreets.isEmpty) {
      // done
      scoreThisTick += baseCarScore + (simulationDuration - timeElaped);
    } else {
      streets[nextStreetName].addCar(processedCar);
    }
  }

  return scoreThisTick;
}

void calculateAndPrintScore() {
  var score = 0;

  for (var i = 1; i < simulationDuration + 1; i++) {
    score += processTick(i);
  }

  print('Score: $score');
}
