using System;
using System.IO;
using DbUp;
using DbUp.Engine.Output;
using Microsoft.Extensions.Configuration;

class Program
{
    static int Main(string[] args)
    {
        var builder = new ConfigurationBuilder()
            .AddEnvironmentVariables()
            .AddCommandLine(args);

        var config = builder.Build();

        var scriptsPath = config["scripts"] ?? Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "scripts");
        var connectionString = config["connectionString"] ?? config["conn"];

        if (string.IsNullOrEmpty(connectionString))
        {
            Console.Error.WriteLine("Usage: DbUpRunner --connectionString " + "\"Server=...;Database=...;Trusted_Connection=true;\"");
            return 2;
        }

        if (!Directory.Exists(scriptsPath))
        {
            Console.Error.WriteLine($"Scripts path not found: {scriptsPath}");
            return 3;
        }

        Console.WriteLine($"Running DbUp against: {connectionString.Split(';')[0]}\nScripts path: {scriptsPath}");

        var upgrader = DeployChanges.To
            .SqlDatabase(connectionString)
        .WithScriptsFromFileSystem(scriptsPath)
            .LogToConsole()
            .Build();

        var result = upgrader.PerformUpgrade();
        if (!result.Successful)
        {
            Console.Error.WriteLine(result.Error);
            return -1;
        }

        Console.WriteLine("Database upgrade completed successfully.");
        return 0;
    }
}
