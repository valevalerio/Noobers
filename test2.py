from sklearn.preprocessing import PolynomialFeatures,FunctionTransformer
import numpy as np
import matplotlib.pyplot as plt
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import make_pipeline
from sklearn.linear_model import Ridge

data = []
hashData = {}


with open("../../Cache/arrowStats.cfg",'r') as f:
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
        
c=0
BigX = []
BigY = []
for h in hashData.keys():
    c+=1
    hashData[h] = (hashData[h][0]-hashData[h][0][0],hashData[h][1])
    positions,velocities = hashData[h]
    #plt.plot(positions[:,0],-positions[:,1],label="shot " +str(c))
    positions[:,0] = abs(positions[:,0])
    for i,position in enumerate(positions[:-1]):
        inputX = np.hstack([position,velocities[i]])
        BigX.append(inputX)
        BigY.append(np.hstack([positions[i+1],velocities[i+1]]))
    #plt.legend()
    #print(c)
#plt.show()
#clf = MLPRegressor(solver='lbfgs', alpha=1e-1,hidden_layer_sizes=(12, 8), random_state=1,activation='identity')

poly = PolynomialFeatures(3)
rid = Ridge(alpha=1.0)
clf = make_pipeline(poly, rid) 
clf.fit(BigX,BigY)
print(len(BigX),"samples",c,"shots")
idx = 600
#print(BigX[idx],BigY[idx],clf.predict([BigX[idx]]))

plt.rcParams["figure.figsize"] = (20,10)

c=0
for h in hashData.keys():
    c+=1
    positions,velocities = hashData[h]

    plt.plot(positions[:,0],-positions[:,1],c='b',label=("Original shot " if c==0 else ''))
    
    inputBigX = []
    posX =[]
    posY =[]
    velx =[]
    vely =[]
    currentPred = []
    for i in range(len(positions)-1):
        if(i == 0):
            currentPred = clf.predict([np.hstack([positions[0],velocities[0]])])
            posX.append(currentPred[0][0])
            posY.append(-currentPred[0][1])
            velx.append(currentPred[0][2])
            vely.append(-currentPred[0][3])
        else:
            currentPred = clf.predict(currentPred)
            posX.append(currentPred[0][0])
            posY.append(-currentPred[0][1])
            velx.append(currentPred[0][2])
            vely.append(-currentPred[0][3])
        #print("currentpred : ", currentPred)
    #for i,position in enumerate(positions[:-1]):
    #    inputBigX.append(np.hstack([position,velocities[i]]))
        
        
    #predX = clf.predict(inputBigX)
    #print(posX,posY)
    
    plt.plot(posX,posY,c='r',linestyle='--',lw=3,label=("Predicted shot " if c==0 else ''))
plt.legend(fontsize=10)
plt.show()
#print(poly.get_feature_names())
#print(rid.coef_)
#print(poly.powers_)

print("SCORE-"*5)
print(clf.score(BigX,BigY))


#print(clf.coefs_)

