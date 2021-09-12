// Archer brain

#define SERVER_ONLY

#include "BrainCommon.as"
#include "ArcherCommon.as"
#include "/Entities/Common/Emotes/EmotesCommon.as"
#include "RidgeRegressorAS.as"
array<array<float>> allShotWeights(30);
array<array<float>> allAimWeights(30);
array<float> fitnessValues(30,0);
array<float> goodArrows(30,0);
array<float> arrowsShot(30,0);
float PI = 3.1415927;
float EulerNum = 2.7182818284;
float constGravity = 9.81;
array<Vec2f> targets(30,Vec2f_zero);


float cosh(float x)
{
	return 0.5*(Maths::Pow(EulerNum,x)+Maths::Pow(EulerNum,-x));
}
float arccosh(float x)
{
	return Maths::Log(x + Maths::Pow(x*x - 1.0,0.5f));
}

array<float> enanchedInput(Vec2f Pos,Vec2f Vel)
{
	array<float> res(8);
	res[0]=Pos.x;
	res[1]=Pos.y;
	res[2]=Vel.x;
	res[3]=Vel.y;
	res[4]=Maths::ATan2(Vel.x,Vel.y);
	res[5]=Maths::Sin(res[4]);
	res[6]=Maths::Cos(res[4]);
	res[7]=Vel.Length();
	return res;
}
float shape_mass                 = 2.0;
float shape_radius               = 0.03;
float shape_drag                 = 0.7;
float velocity 					 = 75;//17.59;
float AirDensity 				 = 0.35;//35; //Air density


float getComplexTrajectory(float ParV,float ParN,float g,float ParX)
{
	float v = ParV; //Velocity
	float n = PI/3.0;// ParN
	float k,t,b1,b2;
	float x=ParX;
	float m = shape_mass; //
	float result=0;
	k = 0.5 * AirDensity *shape_radius*shape_drag;
	b1 = Maths::Sqrt(m/(g*k))* Maths::ATan(v*Maths::Sin(n) * Maths::Sqrt(k/(m*g)));
	b2 = Maths::Sqrt(m/(g*k))*(Maths::ATan(v*Maths::Sin(n)* Maths::Sqrt(k/(m*g))) +
						arccosh(Maths::Sqrt(((k*v*v)/(m*g))*Maths::Sin(n)*Maths::Sin(n)+1.0)));
	
	t = (m/(k*v*Maths::Abs(Maths::Cos(n)))) * (Maths::Pow(EulerNum,(k*x)/m)-1.0);
	//print(" b1 is "+b1+" b2 is "+b2+" t is "+t);
	if (0<t and t <b1)
		result = (m/k)*Maths::Log(Maths::Cos(t*Maths::Sqrt((g*k)/m)-Maths::ATan(v*Maths::Sin(n) * Maths::Sqrt(k/(m*g))))) + 
		(m/(2.0*k))*Maths::Log(((k*v*v)/(m*g))*(Maths::Sin(n)*Maths::Sin(n)+1));
	if (t>b1)
		result = -(m/k)*Maths::Log(cosh(t*Maths::Sqrt((g*k)/m)-Maths::ATan(v*Maths::Sin(n) * Maths::Sqrt(k/(m*g))))) + 
		(m/(2.0*k))*Maths::Log(((k*v*v)/(m*g))*(Maths::Sin(n)*Maths::Sin(n)+1));
	return result;
}
float getCurrGravity(float curr_vel)
{    

	if (curr_vel > 13.5f) // 2) if the arrow is moving fast 
	{
		return (0.1f); // gravity has 1/10 of normal influence on the shape
	}
	else //otherwise
	{
		return (Maths::Min(1.0f, 1.0f / (curr_vel * 0.1f))); // if arrow is not moving fast make gravity come back to normal
	}

}
float ParabolicTrajectorydiX(Vec2f pos1,Vec2f pos2,float v0,float x,float &out angle,float g)
{
	Vec2f tangente = pos2-pos1;
	float theta0 = Maths::ATan2(tangente.x,tangente.y)-(PI/2.0);
	float denominator = v0*Maths::Cos(theta0);
	angle = theta0;
	return Maths::Tan(theta0)*x- (x*x)*(0.5)*(g/(denominator*denominator));

}
Vec2f newParabolicFun(Vec2f pos1,Vec2f pos2,float v0,float t,float g)
{
	Vec2f result;
	Vec2f tangente = pos2-pos1;
	float theta0 = Maths::ATan2(tangente.x,tangente.y)-(PI/2.0);
	result.x = v0*Maths::Cos(theta0);
	result.y =-( v0*Maths::Sin(theta0)*t-0.5*g*t);
	return result;
}
float ParabolaPassantePerunPuntoDataLaTangentediX(Vec2f pos1,Vec2f pos2,float a,float x){
	//print("pos1pos2"+pos1+" " +pos2);
	float b,c,q,m;
	float x1 = pos1.x, y1 = pos1.y;
	float x2 = pos2.x, y2 = pos2.y;
	if (x1==x2) return x2;
	m = (y1-y2)/(x1-x2);
	q = -m*x1+y1;
	b = -2.0*a*x1+m;
	
	c = y1-a*x1*x1-b*x1;
	//print("parabola is:"+a+"X^2 + "+b+"X + "+c);
	return a*x*x+b*x+c;

}
float ParabolaPassanteperDuePuntidiX(Vec2f pos1,Vec2f pos2,float a,float x){
	//print("pos1pos2"+pos1+" " +pos2);
	float b,c;
	float x1 = pos1.x, y1 = pos1.y;
	float x2 = pos2.x, y2 = pos2.y;
	if (x1==x2) return x2;
	b = (-y1+y2-a*(x2*x2-x1*x1))/(x2-x1);
	c = y1-a*(x1*x1)-x1*b;
	//print("parabola is:"+a+"X^2 + "+b+"X + "+c);
	return a*x*x+b*x+c;

}

int myAtoi(string num){
	return parseInt(num.substr(2,-1));
}
float getAIBoolShot(CBlob@ blob,CBlob@ target,Vec2f aimPos)
{
	int idx = myAtoi(blob.getPlayer().getUsername());
	bool verbose = false;// (XORRandom(1000)<10) && (idx==argmax(fitnessValues));
	//printInt("my idx",idx);
	array<float> ShotWeights = allShotWeights[idx];
	//print("Shot weights");
	//print(Array2String(ShotWeights));
	float bias = ShotWeights[0];
	float x1 = (1.0*blob.get_u32("fire time"))/(1.0*ArcherParams::shoot_period);
	float x2 = (1.0*blob.get_u32("fire time"))/(2.0*ArcherParams::shoot_period);
	float x3 = (1.0*blob.get_u32("fire time"))/(3.0*ArcherParams::shoot_period);
	float x4 = NumArrows(blob)/30.0;
	Vec2f col;
	
	float x5;
	if (!getMap().rayCastSolid(blob.getPosition(), aimPos, col)) x5 = 1.0; else x5 = -1.0;
	//bias +linear combination of other features
	float output =  ShotWeights[1]*x1 +
					ShotWeights[2]*x2 +
					ShotWeights[3]*x3 +
					ShotWeights[4]*x4 +
					ShotWeights[5]*x5 +
					bias;
	//What is the sintax for Maths::Tanh? It does not found the matching signature!
	//return Maths::Tanh(output); 


	if (verbose)
	{			
				string name = blob.getPlayer().getUsername();
				array<float> inputLR = 
				   {bias,
				    ShotWeights[1]*x1,
					ShotWeights[2]*x2,
					ShotWeights[3]*x3,
					ShotWeights[4]*x4,
					ShotWeights[5]*x5
					};
				print(Array2String(inputLR));
				printFloat(name+" SHOT output ",output);
	}


	return Maths::Cos(output); 
}
float getAIAim(CBlob@ blob,CBlob@ target)
{
	int idx = myAtoi(blob.getPlayer().getUsername());
	bool verbose = false;//(XORRandom(1000)<10) && (idx==argmax(fitnessValues));
	//printInt("my idx",idx);
	array<float> AimWeights = allAimWeights[idx];
	float bias = AimWeights[0];

	Vec2f targetVector = target.getPosition() - blob.getPosition();
	float x9 = (isVisible(blob,target) ? 1.0 : 0.0 )*Maths::ATan2(targetVector.x, -targetVector.y);
	float nintyRad = PI/2;
	float angleStep = -PI/(2*8);
	float x10;
	if (target.getPosition().x<blob.getPosition().x) x10 = 1.0; else x10 = -1.0;
	float c=0;
	float customAngle = nintyRad+angleStep*c;
	Vec2f otherP;
	
	float x1 =  customAngle*(isLineOfSight(target, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x2 = 	customAngle*(isLineOfSight(target, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x3 = 	customAngle*(isLineOfSight(target, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x4 = 	customAngle*(isLineOfSight(target, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x5 = 	customAngle*(isLineOfSight(target, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x6 = 	customAngle*(isLineOfSight(target, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x7 = 	customAngle*(isLineOfSight(target, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x8 = 	customAngle*(isLineOfSight(target, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	c = 0;
	angleStep = angleStep*-1.0;
	customAngle = nintyRad+angleStep*c;
	
	float x1Mine =  customAngle*(isLineOfSight(blob, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x2Mine = 	customAngle*(isLineOfSight(blob, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x3Mine = 	customAngle*(isLineOfSight(blob, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x4Mine = 	customAngle*(isLineOfSight(blob, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x5Mine = 	customAngle*(isLineOfSight(blob, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x6Mine = 	customAngle*(isLineOfSight(blob, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x7Mine = 	customAngle*(isLineOfSight(blob, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}
	float x8Mine = 	customAngle*(isLineOfSight(blob, customAngle,targetVector.Length()/2.0,otherP) ? 1 : 0); c+=1; customAngle = nintyRad+angleStep * (c * x10); if (verbose && false) {printVec2f("myPos is ",target.getPosition()); printVec2f("otherP is ",otherP);}


	//bias +linear combination of other features
	float output = 
	AimWeights[1]*x1 +
	AimWeights[2]*x2 +
	AimWeights[3]*x3 +
	AimWeights[4]*x4 +
	AimWeights[5]*x5 +
	AimWeights[6]*x6 +
	AimWeights[7]*x7 +
	AimWeights[8]*x8 +
	AimWeights[9]*x9 +
	AimWeights[10]*x10 +
	AimWeights[11]*x1Mine+
	AimWeights[12]*x2Mine+
	AimWeights[13]*x3Mine+
	AimWeights[14]*x4Mine+
	AimWeights[15]*x5Mine+
	AimWeights[16]*x6Mine+
	AimWeights[17]*x7Mine+
	AimWeights[18]*x8Mine+
	bias;
	//What is the sintax for Maths::Tanh? It does not found the matching signature!
	//return Maths::Tanh(output);
	if (verbose)
	{			
				string name = blob.getPlayer().getUsername();
				print("I'AM "+name+" my score is "+maxim(fitnessValues));
				print("Enemy is at "+(x10>0.0 ? "Left" : "Right")+" x9=" + x9);
				array<float> inputLR = 
				   {x1,
					x2,
					x3,
					x4,
					x5,
					x6,				
					x7,
					x8,				
					AimWeights[9]*x9,
					AimWeights[10]*x10,
					bias
					};
				array<float> inputLRMINE =
				{
					x1Mine,
					x2Mine,
					x3Mine,
					x4Mine,
					x5Mine,
					x6Mine,
					x7Mine,
					x8Mine
				};
				print(Array2String(inputLR));
				print(Array2String(inputLRMINE));
				printFloat(name+"output ",output);
	}
	return output; 
}
string Array2String(array<Vec2f> arr)
{
	string s = "";
	int i=0;
	for (;i<arr.length();i++){
		s+=arr[i]+"; ";
	}
	return s;
}
string Array2String(array<double> arr)
{
	string s = "";
	int i=0;
	for (;i<arr.length();i++){
		s+=arr[i]+"; ";
	}
	return s;
}
string Array2String(array<float> arr)
{
	string s = "";
	int i=0;
	for (;i<arr.length();i++){
		s+=arr[i]+"; ";
	}
	return s;
}
float fit_score(CBlob@ this)
{
	float score=0;
	
	int na = NumArrows(this);
	score = (na<10 ? na : (10-(na-10) ));
	int kills = this.getPlayer().getKills();
	int assists = this.getPlayer().getAssists();
	score = score + (kills*100+assists*30)*(na+1);
	this.getPlayer().setScore(score);
	return score;
}
float maxim(array<float>arr)
{
	float MAX = -10000;
	for (int i=0;i<arr.length;i++)
	{
		if (arr[i]>MAX){
			MAX = arr[i];
		}
	}
	return MAX;
}
int argmax(array<float>arr)
{
	int argMaxIdx = -1;
	float m = maxim(arr);
	return arr.find(m);
}
int NumArrows(CBlob@ this)
{
	const string[] arrowTypeNames = { "mat_arrows",
                                  "mat_waterarrows",
                                  "mat_firearrows",
                                  "mat_bombarrows"
                                };
	ArcherInfo@ archer;
	if (!this.get("archerInfo", @archer))
	{
		return -1;
	}
	if (archer.arrow_type >= 0 && archer.arrow_type < arrowTypeNames.length)
	{
		return this.getBlobCount(arrowTypeNames[archer.arrow_type]);
	}
	return -1;
}
void onRender(CSprite@ this){
	int idx,team;
	if (this.getBlob().getPlayer() !is null){
		idx = myAtoi(this.getBlob().getPlayer().getUsername());
		team = this.getBlob().getPlayer().getTeamNum();
	}
	else
		return;
	int Color3rd = 120;
	//GUI::DrawLine(this.getBlob().getPosition(),this.getBlob().getAimPos(), SColor(255,255,Color3rd,255));
	float amount = 150.0;//3.0*this.getBlob().get_u32("fire time");
	Vec2f halfParab = (this.getBlob().getAimPos()-this.getBlob().getPosition());
	float tmp;
	//halfParab.x = 
	halfParab = Vec2f(amount*((halfParab.x)/halfParab.Length()),(amount*(halfParab.y)/halfParab.Length()));
	halfParab = this.getBlob().getPosition()+halfParab;
	//GUI::DrawLine(this.getBlob().getPosition(),halfParab, SColor(0,100*this.getBlob().getPlayer().getTeamNum(),0,255));
	
	//GUI::DrawLine(this.getBlob().getPosition(),targets[idx], SColor(Color3rd,0,Color3rd,255));
	Vec2f pos1 = this.getBlob().getPosition()+Vec2f(this.isFacingLeft() ? 2 : -2, -2);//+Vec2f(0.0,(team==0 ? -20.0 : 0.0));
	if (true or !this.getBlob().getPlayer().isBot()){

		float steps = 10.0;
		float step = 5.0;//Maths::Abs((pos1-halfParab).x)/steps;
		if (pos1.x>this.getBlob().getAimPos().x) step*=-1.0;
		int color_step = 255/steps;
		Vec2f first =  pos1;
		Vec2f last = this.getBlob().getAimPos();//halfParab;// + Vec2f(0.0,(team==0 ? -20.0 : 0.0));//;
		float yy;
		Vec2f prec=first;
		Vec2f corr;
		float theta;
		float a;
		for (float j=0.0;j<=-10.0;j+=1.0){
			a = velocity*(j==0.0 ? 1.0 :
							(j==1.0 ? (1.0f / 3.0f) : (4.0f / 5.0f))
						  );
			
			Vec2f c1=Vec2f_zero;
			Vec2f p1=Vec2f_zero;
			Vec2f firstPointInComplexTraj = Vec2f_zero;
			prec=first;
			for (int i=0;i<steps*10;i++)
			{
				yy = ParabolicTrajectorydiX(pos1,last,
															a,
															step*i,
															theta,
															constGravity
															);
				corr = Vec2f(first.x + step*i,first.y-yy);
				//print("step "+i+")prec is "+prec+" corr is "+corr);
				GUI::DrawLine(prec,corr, SColor(0,color_step*i*team,color_step*i,255));
				
				prec = corr;
				//theta += (theta > PI/2.0 or theta < -PI/2.0) : 
				c1.x = Maths::Abs(step*i);
				c1.y = -getComplexTrajectory(a,theta,constGravity,c1.x);
				c1.x *= (this.isFacingLeft() ? -1.0 : 1.0);
				if (i==1.0) firstPointInComplexTraj = c1;
				else GUI::DrawLine(pos1+p1-firstPointInComplexTraj,pos1+c1-firstPointInComplexTraj,SColor(255,255,255,255));
				p1=c1;
			}
			
			
			float Hmax = 1.0/(2.0*constGravity)*(a*Maths::Sin(theta))*(a*Maths::Sin(theta));
			Vec2f pmin, pmax;
			pmin.x = 0;
			pmin.y = pos1.y-Hmax;
			pmax.y = pmin.y;
			pmax.x = 300.0;
			GUI::DrawLine(pmin,pmax,SColor(0,0,255,255));
		}

		//array<Vec2f> simulatedTraj = doShotSim(this.getBlob().getAimPos(),pos1, 0.1f);
		//if (XORRandom(200)==0 and false)
		//	for (int iii=0;iii<simulatedTraj.length;iii++){
		//		print(iii+")"+simulatedTraj[iii]);
		//	}
		//	//print(Vec2fArray2String(simulatedTraj));
		//	//print("theta is "+theta+"(angles)"+(theta/PI)*180+" tg is "+Maths::Tan(theta)+" Cos is"+Maths::Cos(theta));
		//
		//
		//for (int i=0; i< simulatedTraj.length-2;i++)
		//{
		//	GUI::DrawLine(pos1+simulatedTraj[i],pos1+simulatedTraj[i+1],SColor(255,255,255,255));
		//}
		Vec2f otherP = pos1+Vec2f(100.0*Maths::Cos(theta),-100.0*Maths::Sin(theta));
		//inpu = array<float>(4);
		//inpu[0] = 127.239;
		//inpu[1] = 152.46;
		//inpu[2] = 2.46812;
		//inpu[3] = 9.17106;
		 
		array<double> predictedOutput(4);
		for (float j=0.0;j<=2.0;j+=1.0)
		{
			a = 17.59*(j==0.0 ? 1.0 :
							(j==1.0 ? (1.0f / 3.0f) : (4.0f / 5.0f))
						  );
			//REGRESSOR INPUT/OUTUPUT	
			Vec2f maxVel = (this.getBlob().getAimPos()-this.getBlob().getPosition());
			maxVel = maxVel*(a/maxVel.Length());
			array<float> inpu={0,0,maxVel.x,maxVel.y};
			for (int k=0;k<4;k++)
					predictedOutput[k]=inpu[k];
			int i=0;
			while(i<300 and !getMap().rayCastSolid(pos1+Vec2f(inpu[0],inpu[1]),
							pos1+Vec2f(predictedOutput[0],predictedOutput[1]), Vec2f()))
			{
				i+=1;
				inpu = enanchedInput(Vec2f(inpu[0],inpu[1]),
									Vec2f(inpu[2],inpu[3]));
				
				predictedOutput = predict(inpu[0],inpu[1],inpu[2],inpu[3],inpu[4],inpu[5],inpu[6],inpu[7]);
				GUI::DrawLine(pos1+Vec2f(inpu[0],inpu[1]),
							pos1+Vec2f(predictedOutput[0],predictedOutput[1]),
							SColor(0,255,0,255));
				//print("inpu "+Array2String(inpu)+" output "+Array2String(predictedOutput));
				for (int k=0;k<4;k++)
					inpu[k]=predictedOutput[k];

			}
		}


		GUI::DrawLine(pos1,otherP, SColor(0,0,0,255));
		corr = last;
	}
}

array<Vec2f> doShotSim(Vec2f cursorpos, Vec2f currentPos, const f32 heightModifier)
{
    Vec2f tScursorpos = cursorpos - currentPos;
	array<Vec2f> res;
	res.resize(0);
	bool fastArrow = false;
    Vec2f currentOffset = (tScursorpos / tScursorpos.Length()) *(fastArrow ? 100.0f : 70.0f) * 1.3f * 1.05f / 10.f;//(f32)(MAP->tilesize);
    Vec2f nextPos = currentPos + currentOffset;

    int count = 0;
    while(count < 1000) //5s should _really_ be long enough.
    {
		currentOffset = currentOffset;// - ((0.0175f) * currentOffset);
        currentOffset.y += (0.1781f)*heightModifier;

        
		
		nextPos = currentPos + currentOffset;
		
        count+=1;

        res.push_back(Vec2f((nextPos.x/8.0f),(nextPos.y/8.0f)));
        currentPos = nextPos;
    }

    return res;
}

void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	string name;
	if (player !is null)
		if (this.isBot() or player.isBot())
		{	

			int idx = myAtoi(player.getUsername());
			//getBestWeightsWithNoise(idx);
			getLRWeights(idx,player.getUsername());
			/*if (fitnessValues[idx]<=0)
			else
			*/	
			
			
			player.setDeaths(0);
			targets[idx]=Vec2f_zero;
			/*print("I've GOT my shit set up " + player.getUsername());
			printFloat("Shot Wheights are",allShotWeights[idx].length);
			printFloat("AIM Wheights are",allAimWeights[idx].length);
			*/
			if (idx==0){
				print("SCORES:"+Array2String(fitnessValues));
			}
		}
}
/*
f32 onPlayerTakeDamage(CRules@ this, CPlayer@ victim, CPlayer@ attacker, f32 DamageScale)
{
	if (attacker !is null && attacker !is victim){
		print("victim is"+victim.getUsername());
		print(attacker.getUsername()+" is the attacker");
	}
	return DamageScale;
}
f32 SimpleonHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	
	print(this.getName()+" is this and hitter blob is "+hitterBlob.getName());
	//getPlayer().getUsername() +" for "+damage);
	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	print(this.getName()+" is this and hit blob is "+hitBlob.getName());
}
*/
f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (hitterBlob.getName()=="arrow")
	{	
		print(this.getPlayer().getUsername()+" is this and hitter blob is "+hitterBlob.getName());
		print(this.getPosition()+" is position, "+velocity.Length()+" is the velocity "+ worldPoint+" is position ");
		if (hitterBlob.getDamageOwnerPlayer().isBot())
		{
			int idx = myAtoi(hitterBlob.getDamageOwnerPlayer().getUsername());
			float arrowDistance = (hitterBlob.getPosition()-targets[idx]).Length();
			if (hitterBlob.getDamageOwnerPlayer().getBlob() !is null)
			{
				float targetDistance = (hitterBlob.getDamageOwnerPlayer().getBlob().getPosition()-targets[idx]).Length();
				float multiplier = (targetDistance/(1.0+arrowDistance));
				/*print("arrow distance is "+arrowDistance);
				print("target distance is "+targetDistance);
				print("arrow distance is "+multiplier);*/
				print("AI "+idx+"s arrow was worth "+multiplier);
				{
					goodArrows[idx]+=multiplier;
					if (this.hasTag("dead")){
						goodArrows[idx]+=(multiplier*multiplier);
					}
				}

			}
		}
	}
	return damage;
}
void onStateChange(CRules@ this, const u8 oldState)
{
	
    if (this.isGameOver())
    {
        CBlob@[] players;
		getBlobsByTag("player", @players);
		for (int i=0;i<players.length;i++){
			CPlayer@ player = players[i].getPlayer();
			if (player.hasTag("dead")) continue;
			if (player.isBot())
			{	
				int idx = myAtoi(player.getUsername());
				if (goodArrows[idx]<=0) continue;
				float gain = (goodArrows[idx]);///(1+arrowsShot[idx]));
				fitnessValues[idx] += gain;
				arrowsShot[idx] = 0.0;
				goodArrows[idx] = 0.0;
				print("new gain for "+player.getUsername()+" is "+gain);
			} 
		}
				
    }
}
void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData )
{
	if (victim.isBot())
	{
		set_emote(victim.getBlob(), Emotes::dots);

		int idx = argmax(fitnessValues);
		int my_idx = myAtoi(victim.getUsername());
		float score = fitnessValues[my_idx];// fit_score(this);
		//if (my_idx%2!=0)
		{
			dumpLRWeightsIfBestOrLoadBestWithNoise(true,my_idx,score);
			print(victim.getUsername()+" Dies scoooore was "+fitnessValues[my_idx]);
		}
			fitnessValues[my_idx] = 0.0;
			goodArrows[my_idx]=0;
		victim.setKills(0);
		victim.setAssists(0);
		
	}

}
array<float> AddNoiseToVec(array<float> arr,float divider)
{
	int i=0;
	for (;i<arr.length();i++){
		arr[i]+=((XORRandom(30000)-15000)*1.0)/divider;//100 for [-1.5,1.5]
	}
	return arr;
}
void getBestWeights(int idx)
{	
	/*printInt("my Atoi",idx);
	print("Load Weights");*/
	ConfigFile cfg = ConfigFile();
	string cost_config_file="../Cache/ArcherWeights.cfg";
	cfg.loadFile(cost_config_file);

	allShotWeights[idx].resize(0);
	cfg.readIntoArray_f32(allShotWeights[idx],"BestShotWeightsAI");
	//allShotWeights[idx] = AddNoiseToVec(allShotWeights[idx],100.0);

	allAimWeights[idx].resize(0);
	cfg.readIntoArray_f32(allAimWeights[idx],"BestAimWeightsAI");
	//allAimWeights[idx] = AddNoiseToVec(allAimWeights[idx],100.0);
	/*AimWeights.resize(0);
	cfg.readIntoArray_f32(AimWeights,"AimWeights"+name);
	AimWeights = AddNoiseToVec(AimWeights,100.0);*/

	//printFloat("Shot Weights are",allShotWeights[idx].length());
	//print(Array2String(allShotWeights[idx]));
	//printFloat("Aim Weights are",AimWeights.length());

}

void getBestWeightsWithNoise(int idx)
{	
	//printInt("my Atoi",idx);
	//print("Load Weights");
	ConfigFile cfg = ConfigFile();
	string cost_config_file="../Cache/ArcherWeights.cfg";
	cfg.loadFile(cost_config_file);

	allShotWeights[idx].resize(0);
	cfg.readIntoArray_f32(allShotWeights[idx],"BestShotWeightsAI");
	allShotWeights[idx] = AddNoiseToVec(allShotWeights[idx],100000.0);

	allAimWeights[idx].resize(0);
	cfg.readIntoArray_f32(allAimWeights[idx],"BestAimWeightsAI");
	allAimWeights[idx] = AddNoiseToVec(allAimWeights[idx],100000.0);
	/*AimWeights.resize(0);
	cfg.readIntoArray_f32(AimWeights,"AimWeights"+name);
	AimWeights = AddNoiseToVec(AimWeights,100.0);*/

	//printFloat("Shot Weights are",allShotWeights[idx].length());
	//print(Array2String(allShotWeights[idx]));
	//printFloat("Aim Weights are",AimWeights.length());

}
void getLRWeights(int srcIdx, string name)
{	
	int idx = myAtoi(name);
	//printInt("my Atoi",idx);
	//print("Load Weights");
	ConfigFile cfg = ConfigFile();
	string cost_config_file="../Cache/ArcherWeights.cfg";
	cfg.loadFile(cost_config_file);

	allShotWeights[idx].resize(0);
	cfg.readIntoArray_f32(allShotWeights[idx],"ShotWeightsAI"+srcIdx);

	allAimWeights[idx].resize(0);
	cfg.readIntoArray_f32(allAimWeights[idx],"AimWeightsAI"+srcIdx);
	/*AimWeights.resize(0);
	cfg.readIntoArray_f32(AimWeights,"AimWeights"+name);
	AimWeights = AddNoiseToVec(AimWeights,100.0);*/

	//printFloat("Shot Weights are",allShotWeights[idx].length());
	//print(Array2String(allShotWeights[idx]));
	//printFloat("Aim Weights are",AimWeights.length());

}

void dumpLRWeightsIfBestOrLoadBestWithNoise(bool addNoise,int my_idx,float my_score)
{
	//printInt("my idx",idx);
	ConfigFile cfg = ConfigFile();
	string cost_config_file = "ArcherWeights.cfg";
	cfg.loadFile("../Cache/"+cost_config_file);
	float best_score = cfg.read_f32("BestScore");
	if (my_score>best_score)
		{
			cfg.add_f32("BestScore",my_score);
			cfg.add_string("BestAimWeights"+"AI",Array2String(allAimWeights[my_idx]));
			cfg.add_string("BestShotWeights"+"AI",Array2String(allShotWeights[my_idx]));	
			cfg.saveFile(cost_config_file);
		}
		
	else
	{
	getBestWeightsWithNoise(my_idx);
	cfg.add_string("AimWeights"+"AI"+my_idx,Array2String(allAimWeights[my_idx]));
	cfg.add_string("ShotWeights"+"AI"+my_idx,Array2String(allShotWeights[my_idx]));	
	cfg.saveFile(cost_config_file);
	}
	
	
	
}

void onInit(CBrain@ this)
{
	InitBrain(this);

}

void onTick(CBrain@ this)
{
	SearchTarget(this, false, true);

	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();

	// logic for target

	this.getCurrentScript().tickFrequency = 29;
	int idx = myAtoi(blob.getPlayer().getUsername());
	if (target !is null && this.getBlob().getPlayer() !is null && target.getPlayer() !is null)
	{
		/*
		if (XORRandom(50)<5){
			print(blob.getPlayer().getUsername()+" is targeting "+ targets[idx]);
		}
		*/
		targets[myAtoi(blob.getPlayer().getUsername())]=target.getPosition();
		
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");
		const bool gotarrows = hasArrows(blob);
		if (!gotarrows)
		{
			strategy = Strategy::retreating;
		}

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		const s32 difficulty = blob.getPlayer().getTeamNum()*14.0;//blob.get_s32("difficulty");
		if ((gotarrows) and (distance > 20.0f * (difficulty+1.0)))
		{				
				strategy = Strategy::chasing;
				//
		}
		else{
			if (!gotarrows) strategy = Strategy::retreating;
			else strategy = strategy = Strategy::attacking;
		}
		
		UpdateBlob(blob, target, strategy);

		// lose target if its killed (with random cooldown)

		if (LoseTarget(this, target))
		{
			strategy = Strategy::idle;
		}
		

		blob.set_u8("strategy", strategy);
	}
	FloatInWater(blob);
	if (XORRandom(5)==0)
		switch (blob.get_u8("strategy"))
			{
				case Strategy::idle:
					set_emote( blob, Emotes::dots);
					break;
				case Strategy::retreating:
					set_emote(blob,Emotes::disappoint);
					break;
				case Strategy::attacking:
					set_emote(blob,Emotes::finger);
					break;
				case Strategy::chasing:
					if (blob.getTeamNum()==0)
						set_emote(blob,Emotes::right);
					else
						set_emote(blob,Emotes::left);
					break;
			}
	if (target==null){
		set_emote( blob, Emotes::question );
	}
}

void UpdateBlob(CBlob@ blob, CBlob@ target, const u8 strategy)
{
	int idx = myAtoi(blob.getPlayer().getUsername());
	if (XORRandom(3)==0){
		targets[idx]=target.getPosition();
		//print("AI"+idx+" has as target"+target.getPlayer().getUsername());
	}
	
	
	
	
	Vec2f targetPos = target.getPosition();
	Vec2f myPos = blob.getPosition();
	if (strategy == Strategy::chasing)
	{
		DefaultChaseBlob(blob, target);
	}
	else if (strategy == Strategy::retreating)
	{
		DefaultRetreatBlob(blob, target);
	}
	else if (strategy == Strategy::attacking)
	{
		3+3;
		//if (idx%2==0)
		//	AttackBlob(blob, target);
	}


	//if (idx%2!=0)
	{
		Vec2f aimPos = AIAiming(blob,target);
		AIShoting(blob,target,aimPos);
	}
}
bool AIShoting(CBlob@ blob,CBlob @target,Vec2f aimPos)
{
	float shotOut = getAIBoolShot(blob,target,aimPos);
	bool AIShotOut = shotOut>0;
	//printFloat("ShotBool",shotOut);
	//printBool("So ->",AIShotOut);
	u32 fTime = blob.get_u32("fire time");
	if (fTime>0 and !AIShotOut) {
		int idx = myAtoi(blob.getPlayer().getUsername());
		arrowsShot[idx]+=1;
	}
	if (AIShotOut)
	{
		blob.set_u32("fire time",fTime+1);
	}
	else
	{
		blob.set_u32("fire time", 0);	
	}
	//AIShotOut = true;
	blob.setKeyPressed(key_action1, AIShotOut);
	return AIShotOut;

}
Vec2f AIAiming(CBlob@ blob, CBlob @target)
{
		Vec2f mypos = blob.getPosition();
		float AIout = getAIAim(blob,target);
		//printFloat("Pure Angle",AIout);
		//AIout*=180.0; //[-180,180]
		
		
		Vec2f targetVector = target.getPosition()-blob.getPosition();
		float x10 = 1.0;
		if ( target.getPosition().x<blob.getPosition().x) x10 = 1.0; else x10 = -1.0;
		float DeltaX = targetVector.Length()*Maths::Cos(AIout);
		float DeltaY = targetVector.Length()*Maths::Sin(AIout);
		DeltaX = target.getPosition().x>blob.getPosition().x ? Maths::Abs(DeltaX) : -Maths::Abs(DeltaX);
		//DeltaY = target.getPosition().y>=blob.getPosition().y ? Maths::Abs(DeltaY) : DeltaY;
		/*
		if (target.getPosition().x>blob.getPosition().x){
			print("my target is at right");
			print("mypos is "+blob.getPosition().x+" DeltaX should be positive and is "+DeltaX);
		}
		printFloat("Deltas",DeltaY);
		printFloat("      ",DeltaX);
		printFloat("TargetVec",targetVector.x);
		printFloat("         ",targetVector.y);*/
		Vec2f targetPos = mypos+Vec2f(DeltaX,DeltaY);//targetVector*targetVector.Length();//Vec2f(DeltaX,DeltaY);
		/*if (myAtoi(blob.getPlayer().getUsername()) % 2 == 0){
			bool worthShooting;
			bool hardShot = targetVector.Length() > 240.0f;
			f32 aimFactor = 1.0f;
			blob.setAimPos(blob.getBrain().getShootAimPosition(targetPos, hardShot, worthShooting, aimFactor));
		}*/
		//if (isVisible(blob,target)) print("difference from target pos is "+(target.getPosition()-targetPos).Length());
		blob.setAimPos(targetPos);
		return targetPos;
		
}


void AttackBlob(CBlob@ blob, CBlob @target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f targetPos = target.getPosition();
	Vec2f targetVector = targetPos - mypos;
	f32 targetDistance = targetVector.Length();
	const s32 difficulty = 15.0;

	JumpOverObstacles(blob);

	const u32 gametime = getGameTime();

	// fire

	if (targetDistance > 25.0f)
	{
		u32 fTime = blob.get_u32("fire time");  // first shot
		bool fireTime = gametime < fTime;

		if (!fireTime && (fTime == 0 || XORRandom(130 - 5.0f * difficulty) == 0))		// difficulty
		{
			const f32 vert_dist = Maths::Abs(targetPos.y - mypos.y);
			const u32 shootTime = Maths::Max(ArcherParams::ready_time, Maths::Min(uint(targetDistance * (0.3f * Maths::Max(130.0f, vert_dist) / 100.0f) + XORRandom(20)), ArcherParams::shoot_period));
			blob.set_u32("fire time", gametime + shootTime);
		}

		if (fireTime)
		{
			bool worthShooting;
			bool hardShot = targetDistance > 30.0f * 8.0f || target.getShape().vellen > 5.0f;
			f32 aimFactor = 0.45f;
			aimFactor += (-0.2f) / float(difficulty > 0 ? difficulty : 1.0f);
			blob.setAimPos(blob.getBrain().getShootAimPosition(targetPos, hardShot, worthShooting, aimFactor));
			if (worthShooting)
			{
				blob.setKeyPressed(key_action1, true);
			}
		}
	}
	else
	{
		blob.setAimPos(targetPos);
	}
}

