import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show Random, max;

final random = Random();

class Car {
  int id;
  int nStreets;

  Queue<String> nextStreets = Queue();

  int timeOnRoad = 0;

  Car({
    this.id,
    this.nStreets,
  });

  void addStreetToRoute(String street) {
    nextStreets.addLast(street);
  }

  /// Returns the name of the next street on the car's route.
  String nextStreet() {
    return nextStreets.removeFirst();
  }

  Car clone() {
    final clonedCar = Car(
      id: id,
      nStreets: nStreets,
    );

    nextStreets.forEach((streetName) {
      clonedCar.addStreetToRoute(streetName);
    });

    return clonedCar;
  }
}

class Street {
  int id;
  int start;
  int end;
  String name;
  int length;

  List<Car> nonQueuedCars = [];
  Queue<Car> trafficLightQueue = Queue();

  Street({
    this.id,
    this.start,
    this.end,
    this.name,
    this.length,
  });

  void addInitialCar(Car car) {
    trafficLightQueue.addLast(car);
  }

  /// Adds a [Car] the the [Street].
  void addCar(Car car) {
    nonQueuedCars.add(car);
  }

  /// Adds a [Car] the the traffic light queue.
  void addCarToTrafficLightQueue(Car car) {
    trafficLightQueue.addLast(car);
  }

  /// Removes the first [Car] from the traffic light queue.
  Car consumeQueuedCar() {
    return trafficLightQueue.removeFirst();
  }

  Street clone() {
    final clonedStreet = Street(
      id: id,
      start: start,
      end: end,
      name: name,
      length: length,
    );

    trafficLightQueue.forEach((car) {
      clonedStreet.addInitialCar(car.clone());
    });

    return clonedStreet;
  }
}

class IncomingStreet {
  String name;
  int greenDuration;

  IncomingStreet({
    this.name,
    this.greenDuration,
  });
}

class Intersection {
  int id;

  List<IncomingStreet> incomingStreets = [];
  int totalGreenLightDuration = 0;

  Intersection({
    this.id,
  });

  void addStreet(Street street, int greenDuration) {
    incomingStreets.add(IncomingStreet(
      name: street.name,
      greenDuration: greenDuration,
    ));

    // update the total green light when a street is added
    totalGreenLightDuration = incomingStreets.fold(
      0,
      (total, e) => total + e.greenDuration,
    );
  }

  /// Finds the name of the next street that will have a green light.
  String nextStreetNameWithGreenLight(int timeElapsed) {
    var internalRemainder = timeElapsed % totalGreenLightDuration;

    IncomingStreet currentIncomingStreet;

    for (var incomingStreet in incomingStreets) {
      currentIncomingStreet = incomingStreet;

      internalRemainder -= incomingStreet.greenDuration;

      if (internalRemainder <= 0) {
        break;
      }
    }

    return currentIncomingStreet.name;
  }

  Intersection clone() {
    return Intersection(
      id: id,
    );
  }
}

class Simulation {
  int id;
  int duration;
  int nCars;
  int baseCarScore;

  Map<String, Street> streets = {};
  Map<int, Intersection> intersections = {};

  int score = 0;
  int fitness = 0;

  Simulation({
    this.id,
    this.duration,
    this.nCars,
    this.baseCarScore,
  });

  /// Used for the initial run.
  void initializeRandomly() {
    for (final street in streets.values) {
      final greenLightDuration = random.nextInt(duration);

      intersections[street.end].addStreet(street, greenLightDuration);
    }
  }

  /// Runs the [Simulation].
  void run() {
    // final stopwatch = Stopwatch()..start();

    for (var i = 1; i < duration + 1; i++) {
      processTick(i);
    }

    // print(
    //   '⏰ Simulation #$id\n   └> took: ${stopwatch.elapsed}\n   └> score $score\n   └> fitness $fitness',
    // );
  }

  void processTick(int timeElapsed) {
    // for each schedule get the next green light
    for (final intersection in intersections.values) {
      if (intersection.incomingStreets.isEmpty) {
        continue;
      }

      driveNonQueuedCarsLeadingToIntersection(
        timeElapsed,
        intersection,
      );

      if (intersection.totalGreenLightDuration == 0) {
        continue;
      }

      final streetNameWithGreenLight =
          intersection.nextStreetNameWithGreenLight(timeElapsed);
      final streetWithGreenLight = streets[streetNameWithGreenLight];

      if (streetWithGreenLight.trafficLightQueue.isEmpty) {
        continue;
      }

      // reward the simulation for each car the passes a traffic light
      fitness += 10;

      final carOnIntersection = streetWithGreenLight.consumeQueuedCar();

      final nextStreetName = carOnIntersection.nextStreet();

      streets[nextStreetName].addCar(carOnIntersection);
    }
  }

  void driveNonQueuedCarsLeadingToIntersection(
    int timeElapsed,
    Intersection intersection,
  ) {
    for (var i = 0; i < intersection.incomingStreets.length; i++) {
      final incomingStreet = streets[intersection.incomingStreets[i].name];

      driveNonQueuedCarsOnStreet(
        timeElapsed,
        incomingStreet,
      );
    }
  }

  void driveNonQueuedCarsOnStreet(
    int timeElapsed,
    Street street,
  ) {
    for (var i = street.nonQueuedCars.length - 1; i >= 0; i--) {
      final car = street.nonQueuedCars[i];

      // check if the car is at the traffic light
      if (car.timeOnRoad == street.length) {
        street.nonQueuedCars.removeAt(i);

        car.timeOnRoad = 0;

        street.addCarToTrafficLightQueue(car);
      } else {
        // drive the car forward
        car.timeOnRoad++;

        // check if the car has finished
        if (car.timeOnRoad == street.length && car.nextStreets.isEmpty) {
          final carScore = baseCarScore + (duration - timeElapsed);

          score += carScore;
          fitness += carScore;

          // remove the car for the simulation
          street.nonQueuedCars.removeAt(i);
        }
      }
    }
  }

  Simulation clone(int newId) {
    final clonedSimulation = Simulation(
      id: newId,
      duration: duration,
      nCars: nCars,
      baseCarScore: baseCarScore,
    );

    streets.forEach((key, street) {
      clonedSimulation.streets[key] = street.clone();
    });

    intersections.forEach((key, intersection) {
      clonedSimulation.intersections[key] = intersection.clone();
    });

    return clonedSimulation;
  }
}

class Generation {
  int id;
  int populationSize;
  double mutationRatio;

  Map<int, Simulation> population = {};
  List<int> breedingPool = [];

  Simulation bestSimulation;
  Simulation fittestSimulation;

  Generation({
    this.id,
    this.populationSize,
    this.mutationRatio,
  });

  void initializeRandomly(Simulation baseSimulation) {
    for (var i = 1; i <= populationSize; i++) {
      final simulation = baseSimulation.clone(i);

      simulation.initializeRandomly();

      population[i] = simulation;
    }
  }

  void runSimulations() async {
    final stopwatch = Stopwatch()..start();

    // run the calculations in parallel
    await Future.wait(population.values.map((simulation) async {
      final completer = Completer();
      final receivePort = ReceivePort();

      receivePort.listen((message) {
        if (message is Simulation) {
          population[message.id] = message;

          if (message.score >= (bestSimulation?.score ?? 0)) {
            bestSimulation = message;
          }

          if (message.fitness >= (fittestSimulation?.fitness ?? 0)) {
            fittestSimulation = message;
          }

          receivePort.close();

          completer.complete();
        }
      });

      await Isolate.spawn(
        runSimulationIsolate,
        [
          receivePort.sendPort,
          simulation,
        ],
      );

      await completer.future;
    }));

    print('🕹 GEN $id simulation\n   └> took: ${stopwatch.elapsed}');

    stopwatch.stop();
  }

  Generation breedNextGeneration(Simulation baseSimulation) {
    final stopwatch = Stopwatch()..start();

    final nextGeneration = Generation(
      id: id + 1,
      populationSize: populationSize,
      mutationRatio: mutationRatio,
    );

    _produceBreedingPool();

    // always keep the best
    nextGeneration.population[1] = _copyBestSimulation(
      1,
      baseSimulation,
    );

    for (var i = 2; i <= populationSize; i++) {
      final simulation = _geneticCrossover(
        i,
        baseSimulation,
      );

      nextGeneration.population[i] = simulation;
    }

    print(
      '👣 GEN ${nextGeneration.id} breeding\n   └> took: ${stopwatch.elapsed}',
    );

    stopwatch.stop();

    return nextGeneration;
  }

  void _produceBreedingPool() {
    for (var simulation in population.values) {
      var maxScore =
          (simulation.baseCarScore + simulation.duration) * simulation.nCars;

      var reproductionChanceRatio = simulation.fitness / maxScore;

      if (reproductionChanceRatio.isNaN) {
        reproductionChanceRatio = 0.0;
      }

      reproductionChanceRatio = max(reproductionChanceRatio, 1 / maxScore);

      final reproductionChance =
          (reproductionChanceRatio * 1000 * 1000).round();

      // print(
      //   '💦 Simulation GEN ${simulation.id}\n   └> max score $maxScore\n   └> fitness ${simulation.fitness}\n   └> reproduction chance: $reproductionChance',
      // );

      for (var i = 0; i <= reproductionChance; i++) {
        breedingPool.add(simulation.id);
      }
    }
  }

  Simulation _copyBestSimulation(
    int childId,
    Simulation baseSimulation,
  ) {
    final child = baseSimulation.clone(childId);

    child.intersections.forEach((key, value) {
      fittestSimulation.intersections[key].incomingStreets
          .forEach((incomingStreet) {
        child.intersections[key].addStreet(
          child.streets[incomingStreet.name],
          incomingStreet.greenDuration,
        );
      });
    });

    return child;
  }

  Simulation _geneticCrossover(
    int childId,
    Simulation baseSimulation,
  ) {
    final parentA = _pickParent();
    var parentB = _pickParent();

    // avoid breeding the same parent which would result in a hard clone
    while (parentA.id == parentB.id) {
      parentB = _pickParent();
    }

    final child = baseSimulation.clone(childId);

    // TODO: improve breeding

    child.intersections.forEach((key, value) {
      if (random.nextBool()) {
        // add intersection from parent A
        parentA.intersections[key].incomingStreets.forEach((incomingStreet) {
          var greenDuration = incomingStreet.greenDuration;

          // mutate
          if (random.nextDouble() > mutationRatio) {
            greenDuration = random.nextInt(child.duration);
          }

          child.intersections[key].addStreet(
            child.streets[incomingStreet.name],
            greenDuration,
          );
        });
      } else {
        // add intersection from parent B
        parentB.intersections[key].incomingStreets.forEach((incomingStreet) {
          var greenDuration = incomingStreet.greenDuration;

          // mutate
          if (mutationRatio > random.nextDouble()) {
            greenDuration = random.nextInt(child.duration);
          }

          child.intersections[key].addStreet(
            child.streets[incomingStreet.name],
            greenDuration,
          );
        });
      }
    });

    return child;
  }

  Simulation _pickParent() {
    final simulationId = breedingPool[random.nextInt(breedingPool.length)];

    return population[simulationId];
  }
}

Future main(List<String> arguments) async {
  if (arguments.length < 2) {
    throw Exception('Invalid amount of arguments.');
  }

  final inputFilePath = arguments[0];
  final outputFilePath = arguments[1];

  final baseSimulation = Simulation(
    id: 0,
  );

  await parseInput(
    baseSimulation,
    inputFilePath,
  );

  final baseGeneration = Generation(
    id: 0,
    populationSize: 64,
    mutationRatio: 0.05, // 5%
  );

  print(
    '🎛 Settings\n   └> population size: ${baseGeneration.populationSize}\n   └> mutation ratio: ${baseGeneration.mutationRatio * 100}%',
  );

  final stopwatch = Stopwatch()..start();

  baseGeneration.initializeRandomly(baseSimulation);

  print('⛓ Setup took ${stopwatch.elapsed}');

  var bestSimulation = baseSimulation;
  var currentGeneration = baseGeneration;

  // number of generations
  for (var i = 0; i < 128; i++) {
    await currentGeneration.runSimulations();

    print(
      '🏁 GEN $i finished\n   └> score: ${currentGeneration.bestSimulation.score}',
    );

    if (currentGeneration.bestSimulation.score > bestSimulation.score) {
      bestSimulation = currentGeneration.bestSimulation;

      print('🎉 NEW! High-score: ${bestSimulation.score}');
    }

    final nextGeneration = currentGeneration.breedNextGeneration(
      baseSimulation,
    );

    currentGeneration = nextGeneration;
  }

  print('🙌 Finished dataset\n   └> took: ${stopwatch.elapsed}');

  stopwatch.stop();

  await printOutput(
    bestSimulation,
    outputFilePath,
  );

  print('🥇 Final score: ${bestSimulation.score}');
}

void runSimulationIsolate(List<dynamic> arguments) {
  SendPort sendPort = arguments[0];
  Simulation simulation = arguments[1];

  simulation.run();

  sendPort.send(simulation);
}

Future parseInput(
  Simulation simulation,
  String inputFilePath,
) async {
  final stopwatch = Stopwatch()..start();

  var lineIndex = 0;
  var nStreets = 0;

  final inputLines = File(inputFilePath)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (String line in inputLines) {
    var lineItems = line.split(' ');

    if (lineIndex == 0) {
      simulation.duration = int.parse(lineItems[0]);
      // nIntersections = int.parse(lineItems[1]);
      nStreets = int.parse(lineItems[2]);
      simulation.nCars = int.parse(lineItems[3]);
      simulation.baseCarScore = int.parse(lineItems[4]);
    } else if (lineIndex <= nStreets) {
      // parse streets
      final streetName = lineItems[2];
      final end = int.parse(lineItems[1]);

      simulation.streets[streetName] = Street(
        id: lineIndex - 1,
        start: int.parse(lineItems[0]),
        end: end,
        name: streetName,
        length: int.parse(lineItems[3]),
      );

      // XXX: might be duplicate, don't care
      simulation.intersections[end] = Intersection(
        id: end,
      );
    } else {
      // parse cars
      final car = Car(
        id: lineIndex - nStreets - 1,
        nStreets: int.parse(lineItems[0]),
      );

      // add car to initial street
      simulation.streets[lineItems[1]].addInitialCar(car);

      // parse route
      for (var i = 2; i < lineItems.length; i++) {
        car.addStreetToRoute(lineItems[i]);
      }
    }

    lineIndex++;
  }

  print('📄 Parsing input\n   └> took: ${stopwatch.elapsed}');

  stopwatch.stop();
}

Future printOutput(
  Simulation simulation,
  String outputFilePath,
) async {
  final stopwatch = Stopwatch()..start();

  final outputSink = File(outputFilePath).openWrite();

  var nIntersection = 0;

  for (final intersection in simulation.intersections.values) {
    final length = intersection.incomingStreets.length;

    if (length > 0) {
      nIntersection++;
    }
  }

  await outputSink.writeln(nIntersection);

  for (final intersection in simulation.intersections.values) {
    final length = intersection.incomingStreets.length;

    if (length > 0) {
      await outputSink.writeln(intersection.id);
      await outputSink.writeln(length);

      for (var i = 0; i < length; i++) {
        final name = intersection.incomingStreets[i].name;
        final duration = intersection.incomingStreets[i].greenDuration;

        await outputSink.writeln('$name $duration');
      }
    }
  }

  await outputSink.close();

  print('📄 Printing output\n   └> took: ${stopwatch.elapsed}');

  stopwatch.stop();
}
