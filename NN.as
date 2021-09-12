class NeuralNetwork
{

    array<array<float>> Layer1;
    array<array<float>> Layer2;
    int NNnumber=0;
    string MYname="DEFAULT";
    NeuralNetwork(int inpt,int hiddenL1,int outputs,float min,float max){
        print("new NN with "+inpt+" inpt and outputs"+outputs+ "and "+hiddenL1+" hidden");
        InitNN(inpt,hiddenL1,outputs,min,max);
    }
    NeuralNetwork(string id){
        print("NN loads from file "+id);
        loadfromFile(id);
        MYname = id;
    }

    float pseudoTanh(float x){
        return (x<-1.0? -1.0 : ((x>1.0) ? 1.0 : x));

    }
     array<float> MatMul(array<array<float>> mat,array<float> x)
    {
        if ((x.length != mat[0].length-1)) print("OH OH len x is"+x.length+ "and mat[0].length is"+mat[0].length);
        array<float> res(mat.length);
        //print("MAT MUL");
        //print("Pre FOr"+res.length+" and mat [0] is"+mat[0].length);
        for (int i=0;i<mat.length;i++){
            res[i]=0;
            int j=0;
            for (;j<mat[i].length-1;j++){
                //print(i+") mat "+mat[i][j]+"  Res"+ res[i]);
                //print("x "+j+" * "+"wheigts "+i+", "+j);
                res[i]+=mat[i][j]*x[j];
            }
            //print("bias "+i+", "+j);
            res[i]+=mat[i][j];

        }
        //print("ended FOr"+res.length);
        for (int i=0;i<mat.length;i++){
            res[i] =pseudoTanh(res[i]);// Maths::Sin(res[i]);//
            //print(i+") res "+res[i]);
        }
        //print("ended other For");
        return res;
    }
    array<array<float>> InitRandomLayer(float max,float min, int inpu,int hiddenUnits)
    {
        array<array<float>> Layer(hiddenUnits);
        for (int i=0;i<hiddenUnits;i++)
        {
            int j=0;
            Layer[i]=array<float>(inpu+1);
            for (j=0;j<inpu+1;j++)
            {
                Layer[i][j]=(XORRandom(100000)/100000.0)*(max-min)+min;
            }
        }
        return Layer;
    }
    void AddNoiseToNetwork(float min,float max){
        Layer1 = AddNoiseToLayer(Layer1,min,max);
        Layer2 = AddNoiseToLayer(Layer2,min,max);
    }
    array<array<float>> AddNoiseToLayer(array<array<float>> mat,float min,float max)
    {
        for (int i=0;i<mat.length;i++){
            mat[i]=AddNoiseToVec(mat[i],min,max);
        }
        return mat;
    }
    array<float> AddNoiseToVec(array<float> arr,float min,float max)
    {
        int i=0;
        for (;i<arr.length();i++){
            arr[i]+=(XORRandom(100000)/100000.0)*(max-min)+min;//100 for [-1.5,1.5]
        }
        return arr;
    }
    void loadfromFile(string name){
        ConfigFile cfg = ConfigFile();
        string cost_config_file = name+".cfg";
        cfg.loadFile("../Cache/"+cost_config_file);
        array<float> neurons();
        cfg.readIntoArray_f32(neurons,"Neurons");
        print(FloatArray2String(neurons));
        int s1 = neurons[0];
        int s2 = neurons[1];
        print("hidden1 "+s1);
        print("hidden2 "+s2);
        Layer1.resize(s1);
        Layer2.resize(s2);
        for (int i=0;i<Layer1.length;i++)
        {   
            Layer1[i].resize(0);
            cfg.readIntoArray_f32(Layer1[i],"L1Neuron"+i);
        }
        for (int i=0;i<Layer2.length;i++)
        {
            Layer2[i].resize(0);
            cfg.readIntoArray_f32(Layer2[i],"L2Neuron"+i);
        }
    }
    void printLayers()
    {
         for (int i=0;i<Layer1.length;i++)
        {
            print("L1Neuron"+i+")"+FloatArray2String(Layer1[i]));
        }
        for (int i=0;i<Layer2.length;i++)
        {
            print("L2Neuron"+i+")"+FloatArray2String(Layer2[i]));
        }
    }
    void saveToFile(string name){
        ConfigFile cfg = ConfigFile();
        string cost_config_file = name+".cfg";
        cfg.loadFile("../Cache/"+cost_config_file);
        array<float> neurons(2);
        neurons[0] = Layer1.length;
        neurons[1] = Layer2.length;
        cfg.add_string("Neurons",FloatArray2String(neurons));

        for (int i=0;i<Layer1.length;i++)
        {
            cfg.add_string("L1Neuron"+i,FloatArray2String(Layer1[i]));
        }
        for (int i=0;i<Layer2.length;i++)
        {
            cfg.add_string("L2Neuron"+i,FloatArray2String(Layer2[i]));
        }
        cfg.saveFile(cost_config_file);
        
    }
    void InitNN(int inpt,int hiddenL1,int outputs,float min,float max)
    {
        Layer1 = InitRandomLayer(min,max,inpt,hiddenL1);
        Layer2 = InitRandomLayer(min,max,hiddenL1,outputs);

        print("NN initialized");
        //print("LAYER1\n"+Mat2String(Layer1));
        //print("LAYER2\n"+Mat2String(Layer2));
    }
    array<float> predict(array<float> inpt)
    {
        //print(FloatArray2String(inpt));
        array<float> out1 = MatMul(Layer1,inpt);
        //print(FloatArray2String(out1));
        array<float> out2 = MatMul(Layer2,out1);
        //print(FloatArray2String(out2));
        return out2;
    }

}

string Mat2String(array<array<float>> mat)
{
    string s = "";
    for (int i=0;i<mat.length;i++){
        s+=FloatArray2String(mat[i])+"\n";
    }
    return s;
}
string FloatArray2String(array<float> arr)
{
	string s = "";
	int i=0;
	for (;i<arr.length();i++){
		s+=arr[i]+"; ";
	}
	return s;
}