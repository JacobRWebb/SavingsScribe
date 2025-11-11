using Amazon.CDK;
using Amazon.CDK.AWS.Lambda;
using Constructs;

namespace SavingsScribe.Infrastructure.Resources;

public class LambdaFunctionProps
{
    public required string LambdaPath { get; set; }
    public required string FunctionName { get; set; }
    public required string Description { get; set; }
    public required string Handler { get; set; }
    public int MemorySize { get; set; } = 512;
    public Duration? Timeout { get; set; } = Duration.Seconds(30);
}

public class LambdaFunction : Construct
{
    public Function Function { get; }

    public LambdaFunction(Construct scope, string id, LambdaFunctionProps props)
        : base(scope, id)
    {
        Function = new Function(
            this,
            id,
            new FunctionProps
            {
                FunctionName = props.FunctionName,
                Description = props.Description,
                Runtime = Runtime.DOTNET_8,
                Handler = props.Handler,
                Code = Code.FromAsset(props.LambdaPath, new Amazon.CDK.AWS.S3.Assets.AssetOptions{}),
                MemorySize = props.MemorySize,
                Timeout = props.Timeout
            }
        );
    }
}
