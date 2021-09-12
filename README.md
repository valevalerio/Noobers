# Noobers
AI for archer

Random Solver for training Neural Networks.
Each bot relies on a bunch of hand coded rules and
the aiming is performed by a NN optimized during the epochs and it is evaluated on some metrics computed during the simulations.
based on the performancies obtained the weights gains more value and remains stored as best ones.

The movement is a stright Jump+Right/Left that leads the bot to the closest target bot of the opposite team.

The input of the NN are:
Categorical: 0/1
  - a fixed number of rays to check if the einvironment obstruct the sights arount the current aim. (3)
  - if a plain line is drawable from the target to the bot is described by the feature about visibility.(1)
Numerical:
  - For each possible shot (low/medium/fast) the closest distance from the bot target and the trajectory of the shot is fed to the NN. (3)
      The physic of the trajectory is computed eninge side, so I built a Linear regressor to compute the porediction of the trajectory, that indeed at some angles has non negligibile error.
  - The current angle of aiming in radians. (1)

Results are interesting and improve the smartness of the AI ArcherBrain in the base, Henri :)
