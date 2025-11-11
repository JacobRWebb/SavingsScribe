using Amazon.CDK;
using Constructs;
using SavingsScribe.Infrastructure.Resources;

namespace SavingsScribe.Infrastructure.Stacks;

public class MainStack : Stack
{
    public MainStack(Construct scope, string id, IStackProps props = null)
        : base(scope, id, props)
    {
        var test = new LambdaFunction(this, "HelloWorld-Lambda", new LambdaFunctionProps
        {
            LambdaPath = "SavingsScribe.HelloWorld.Lambda/SavingsScribe.HelloWorld.Lambda",
            FunctionName = "HelloWorldFunction",
            Description = "A simple Hello World Lambda function",
            Handler = "SavingsScribe.Functions.HelloWorld::SavingsScribe.Functions.HelloWorld.Function::FunctionHandler",
            MemorySize = 256,
            Timeout = Duration.Seconds(15)
        });
    }
}
