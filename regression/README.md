# Build result polling regressions

These checks use shared simulated API responses. They never request upload credentials, upload a file, or call PGYER/COS.
The PHP check replaces the transport throughout upload; Java/C# inject the response provider into the production polling loop; Shell replaces curl and sleep.

They cover immediate success, both processing codes (1246/1247), terminal errors (including unknown codes and Unicode messages), processing followed by failure, missing messages, invalid responses, and transport failures. Shell retains its pre-existing retries on transport failures. Each case checks the exact request count, so fetching again after a terminal response fails the regression.

Run from the repository root with PHP 7.4+, Python 3, Bash, JDK 8+/Maven, and .NET SDK 8:

```sh
php regression/php/polling.php regression/build-info-cases.json
python3 regression/shell/polling.py regression/build-info-cases.json

mvn -q -f java-demo/pom.xml package dependency:build-classpath -Dmdep.outputFile=/tmp/pgyer-poll-java-cp
mkdir -p /tmp/pgyer-poll-java-classes
javac -encoding UTF-8 -cp "java-demo/target/classes:$(cat /tmp/pgyer-poll-java-cp)" -d /tmp/pgyer-poll-java-classes regression/java/PollingRegression.java
java -cp "/tmp/pgyer-poll-java-classes:java-demo/target/classes:$(cat /tmp/pgyer-poll-java-cp)" com.pgyer.uploader.PollingRegression regression/build-info-cases.json

dotnet run --project regression/csharp/PollingRegression.csproj -- regression/build-info-cases.json
```

The production poll cap remains 60 attempts. This change does not introduce an overall wall-clock deadline or change upload retry policies.
