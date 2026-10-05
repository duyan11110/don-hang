# The fake payment gateway's image: one small project, no other code copied in.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY global.json Directory.Packages.props ./
COPY fake-gateway/FakeGateway.csproj fake-gateway/
RUN dotnet restore fake-gateway/FakeGateway.csproj
COPY fake-gateway/ fake-gateway/
RUN dotnet publish fake-gateway/FakeGateway.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "FakeGateway.dll"]
