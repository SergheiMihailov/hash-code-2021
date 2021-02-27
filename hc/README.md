## A genetic algorithm to find the best traffic light sequence.

### Overview

The program creates a initial generation with a population size of 64 simulations, which each have random green light sequences.
Next, the program runs the simulations and evaluates their score. All simulations are evaluated in parallel, exploiting Dart isolates to speed up the simulation process. Based on the score of the simulation it have a chance to reproduce (fitness.) The program then creates a new generation by crossing over intersections form two simulations for the previous generation. This repeats for 128 generations, and then the program outputs the best simulation.

### Next steps

There is room for improvement in both the fitness function as well as the genetic crossover.

Currently the fitness of a simulation is equal to the problem score plus an extra point for each car that passes any green light. A new simulation gets all the traffic light durations for a given intersection from either parent A or B. Each road leading into an intersection has a 1% chance of mutating into a random value.

Created from templates made available by Stagehand under a BSD-style
[license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
