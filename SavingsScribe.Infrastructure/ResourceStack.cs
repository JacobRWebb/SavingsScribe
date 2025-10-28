using Amazon.CDK;
using Constructs;

namespace SavingsScribe.Infrastructure
{
    public class ResourceStack : Stack
    {
        internal ResourceStack(Construct scope, string id, IStackProps props = null) : base(scope, id, props)
        {
            // The code that defines your stack goes here
        }
    }
}
