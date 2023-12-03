import math

shape_mass = 2.0
shape_radius = 0.03
shape_drag = 0.7
velocity = 75
AirDensity = 0.35
g = 9.82 
def getComplexTrajectory(ParV, ParN, g, ParX):
    v = ParV
    n = math.pi / 3.0
    x = ParX
    m = shape_mass
    result = 0
    k = 0.5 * AirDensity * shape_radius * shape_drag
    b1 = math.sqrt(m / (g * k)) * math.atan(v * math.sin(n) * math.sqrt(k / (m * g)))
    #b2 = math.sqrt(m / (g * k)) * (math.atan(v * math.sin(n) * math.sqrt(k / (m * g))) + \
    #                                math.acosh(math.sqrt(((k * v * v) / (m * g)) * math.sin(n) * math.sin(n) + 1.0)))
    t = (m / (k * v * abs(math.cos(n)))) * (math.exp((k * x) / m) - 1.0)

    if (0 < t or t < b1):
        result = (m / k) * math.log(math.cos(t * math.sqrt((g * k) / m) - math.atan(v * math.sin(n) * math.sqrt(k / (m * g))))) + \
                  (m / (2.0 * k)) * math.log(((k * v * v) / (m * g)) * (math.sin(n) * math.sin(n) + 1))
    if (t > b1):
        result = -(m / k) * math.log(math.cosh(t * math.sqrt((g * k) / m) - math.atan(v * math.sin(n) * math.sqrt(k / (m * g))))) + \
                  (m / (2.0 * k)) * math.log(((k * v * v) / (m * g)) * (math.sin(n) * math.sin(n) + 1))
    return result

import numpy as np
import matplotlib.pyplot as plt

# Define the constants
g = 9.81  # gravitational acceleration
ParN = math.pi / 3.0  # angle
ParX = 100  # distance

# Define the constants
velocity = 75
theta = np.pi / 3.0  # angle
constGravity = 9.81  # gravitational acceleration
steps = 100
step = 0.1
color_step = 255 / steps
team = 1
first = np.array([0, 0])
last = np.array([100, 0])
pos1 = np.array([0, 0])

for j in np.arange(0.0, -10.0, -1.0):
    a = velocity * (1.0 if j == 0.0 else (1.0 / 3.0 if j == 1.0 else 4.0 / 5.0))

    c1 = np.array([0, 0])
    p1 = np.array([0, 0])
    firstPointInComplexTraj = np.array([0, 0])
    prec = first

    # Loop over a range of steps
    for i in range(steps * 10):
        c1[0] = abs(step * i)
        c1[1] = -getComplexTrajectory(a, theta, constGravity, c1[0])
        c1[0] *= -1 #if isFacingLeft else 1

        if i == 1:
            firstPointInComplexTraj = c1
        else:
            # Draw a line from pos1 + p1 - firstPointInComplexTraj to pos1 + c1 - firstPointInComplexTraj
            plt.plot([pos1[0] + p1[0] - firstPointInComplexTraj[0], pos1[0] + c1[0] - firstPointInComplexTraj[0]],
                     [pos1[1] + p1[1] - firstPointInComplexTraj[1], pos1[1] + c1[1] - firstPointInComplexTraj[1]], color='k')

        p1 = c1

plt.show()