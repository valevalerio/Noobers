from typing import ContextManager
from sklearn.preprocessing import PolynomialFeatures
import numpy as np
import matplotlib.pyplot as plt
from sklearn.pipeline import make_pipeline
from sklearn.linear_model import Ridge

def newDataPoint(oldx):
    posx = (oldx[0])
    posy = (oldx[1])
    velx = (oldx[2])
    vely = (oldx[3])
    #posx,posy,velx,vely
    theta = np.arctan2(velx,vely)
    ink,ink2 = np.sin(theta),np.cos(theta)
    #atan2(velx,vely)=theta, cos & sin of theta, magnitude of velocity
    x = np.array([velx,vely])
    mag = sum(x*x)**0.5
    newx = [posx,posy,velx,vely,theta,ink,ink2,mag]
    return newx
print("opening file")
data = []
hashData = {}
with open("./arrowStats.cfg",'r') as f: #"../../Cache/arrowStats.cfg"
    for line in f:
        data.append(line)

        eeee = line.split('=')
        n,d = eeee[0],eeee[1]
        k = n.find("(")
        p0,v0 = n[k:].split("_")
        key = p0+v0
        if key not in hashData:
            hashData[key]=[],[]

        dataPoints=[]
        for p in d.split(";")[:-1]:
            p = p.strip()[1:-1].split(',')
            p1 = float(p[0])
            p2 = float(p[1])
            dataPoints.append((p1,p2))
        if n[0]=='P':#Positions
            hashData[key]=np.array(dataPoints),hashData[key][1]
        else:
            hashData[key]=hashData[key][0],np.array(dataPoints)
        
print("done")
c=0
BigX = []
BigY = []
validationSet = []
for h in hashData.keys():
    c+=1
    if c in validationSet:
        continue
    hashData[h] = (hashData[h][0]-hashData[h][0][0],hashData[h][1])
    #hashData[h][0][:,0] = np.abs(hashData[h][0][:,0])
    #hashData[h][1][:,0] = np.abs(hashData[h][1][:,0])
    
    positions,velocities = hashData[h]
    print(h)
    x = velocities[0]
    magnitude = sum(x*x)**0.5
    #if x[1]<-10:# and magnitude>10:
    #    continue
    
    #plt.plot(positions[:,0],-positions[:,1],label="shot " +str(c))
    #plt.plot(velocities[:,0],velocities[:,1],label="shot " +str(c))
    #plt.scatter(velocities[:,0],velocities[:,1],label="shot " +str(c))
    #plt.scatter(velocities[0,0],velocities[0,1],c='g',lw=3.0)
    for i,position in enumerate(positions[:-1]):
        inputX = newDataPoint(np.hstack([position,velocities[i]]))
        BigX.append(inputX)
        BigY.append(np.hstack([positions[i+1],velocities[i+1]]))
    #plt.legend()
    #print(c)
#plt.title(h)
#plt.show()
BigX = np.array(BigX)
BigY = np.array(BigY)
poly = PolynomialFeatures(3)
rid = Ridge()
from sklearn.preprocessing import StandardScaler
clf = make_pipeline(poly,StandardScaler(), rid) 
from sklearn.neural_network import MLPRegressor
#clf = MLPRegressor(solver='lbfgs', alpha=1e-3,hidden_layer_sizes=(128), random_state=1,activation='identity')
#model = MLPRegressor(solver='adam', alpha=1e-3,hidden_layer_sizes=(20,8), random_state=1,activation='identity',max_iter=900)

clf.fit(BigX,BigY)

#print(clf.loss_)
print(len(BigX),c,"shots")
idx = 420
print(BigX[idx],clf.predict([BigX[idx]]))
print(BigY[idx]-clf.predict([BigX[idx]]))
#input()
plt.rcParams["figure.figsize"] = (20,10)

c=0
shots_force = np.zeros(3)
axPos = plt.subplot(1,2,1)
axVel = plt.subplot(1,2,2)
for h in hashData.keys():
    c+=1
    positions,velocities = hashData[h]
    x = velocities[0]
    magnitude = sum(x*x)**0.5
    #if x[1]<-10:
    #    continue
    #if magnitude>10:# and magnitude>10:
    #    continue
    #plt.subplot(11,11,c)
    axPos.plot(positions[:,0],-positions[:,1],c='b',label=("Original shot " if c==4 else ''))
    axVel.plot(velocities[:,0],-velocities[:,1],c='b',label=("Original shot " if c==4 else ''))
    inputBigX = []
    posX =[]
    posY =[]
    velx =[]
    vely =[]
    currentPred = []
    for i in range(len(positions)-1):
        if(i == 0):
            newInput = newDataPoint(np.hstack([positions[0],velocities[0]]))
            currentPred = clf.predict([newInput])
            posX.append(currentPred[0][0])
            posY.append(-currentPred[0][1])
            velx.append(currentPred[0][2])
            vely.append(-currentPred[0][3])
        else:
            currentPred = clf.predict([newDataPoint(currentPred[0])])
            posX.append(currentPred[0][0])
            posY.append(-currentPred[0][1])
            velx.append(currentPred[0][2])
            vely.append(-currentPred[0][3])
        #print("currentpred : ", currentPred)
    #for i,position in enumerate(positions[:-1]):
    #    inputBigX.append(np.hstack([position,velocities[i]]))
        
        
    #predX = clf.predict(inputBigX)
    print(len(velx),len(vely))

    axPos.plot(posX,posY,c='r',linestyle='--',label=("Predicted shot " if c==1 else ''))
    axVel.plot(velx,vely,c='r',linestyle='--',label=("Predicted shot " if c==1 else ''))
    colorPlot = 'r' if magnitude > 15.0 else ('y' if magnitude < 6 else 'g')
    idxForce = 2 if magnitude > 15.0 else (0 if magnitude < 6 else 1)
    shots_force[idxForce]+=1
    axPos.scatter(positions[0,0],-positions[0,1],c=colorPlot,lw=1.0)
    axVel.scatter(velocities[0,0],-velocities[0,1],c=colorPlot,lw=1.0)
plt.legend(fontsize=22)
plt.show()
#print(clf.coefs_)
print("SCORE-"*5)
print(clf.score(BigX,BigY))
print(shots_force)
print(poly.get_feature_names_out())

def get_poly_angelscript_equations_strings():
    ASfunctionName = "array<double> predict("+", ".join(["float x"+str(i) for i in range(poly.n_input_features_)])+")\n{\n"
    ASreturn = "\t"
    powers = poly.powers_
    coefficients = rid.coef_
    coefLenght = len(poly.get_feature_names())
    equations = [""]*len(coefficients)
    caching = [""]
    for i in range(2,poly.get_params()["degree"]+1):
        for ii in range(poly.n_input_features_):
            caching[0] += "\t"+f"double x{ii}{i} = Maths::Pow(x{ii},{i});\n"
    for thing in range(len(equations)):
        equations[thing] += str(rid.intercept_[thing]) + "+"
    for count, coef in enumerate(coefficients):
        #print("INLOOP", coef)
        for i, name in enumerate(poly.get_feature_names()):
            if coef[i] == 0 : #if coef is = 0, then the whole term become zero, hence we can skip this iteration
                continue
            equations[count] += f"{str(coef[i])}"
            for inputNb, exponent in enumerate(powers[i]):
                if exponent == 0:
                    continue
                if exponent == 1:
                    equations[count] += f"*x{inputNb}"
                else:
                    equations[count] += f"*x{inputNb}{exponent}"
            if i < coefLenght-1:
                equations[count] += "+"
        if equations[count][-1]=="+":
            equations[count]= equations[count][:-1]
    ASreturn+="\tarray<double> res;\n"
    ASreturn+= "".join(['\tres.insertLast(q'+str(j)+");\n" for j,_ in enumerate(equations)])
    ASreturn+="\treturn res;\n}"
    return [ASfunctionName] + caching + equations +[ASreturn]

if False:
    with open('RidgeRegressorAS.as',"w") as file:
        l = get_poly_angelscript_equations_strings()
        for i, element in enumerate(l):
            variableString = ""
            if i <= 1 or i==len(l)-1:
                file.write(f"{element}")
            else:
                file.write(f"\tdouble q{i-2} = {element};\n")



'''
coefficients = rid.coef_
for count, coef in enumerate(coefficients):
    plt.barh(np.arange(len(coef)),coef)
    plt.yticks(np.arange(len(coef)),poly.get_feature_names())
    plt.show()
'''


'''
print(rid.coef_)
print(poly.powers_)
'''