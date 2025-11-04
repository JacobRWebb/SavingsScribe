using Amazon.CDK;
using SavingsScribe.Infrastructure.Stacks;

namespace SavingsScribe.Infrastructure
{
    sealed class Program
    {
        public static void Main(string[] _)
        {
            var app = new App();

            var mainStack = new MainStack(app, "MainStack", new StackProps
            {

            });

            app.Synth();
        }
    }
}
