# The fake payment gateway's image: one small project, no other code copied in.
FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:de4fe90a98845d75910b9769662465c84de1a934665c431279d1382b2bddc02b AS build
WORKDIR /src
COPY global.json Directory.Packages.props Directory.Build.props ./
COPY fake-gateway/FakeGateway.csproj fake-gateway/packages.lock.json fake-gateway/
RUN dotnet restore fake-gateway/FakeGateway.csproj --locked-mode
COPY fake-gateway/ fake-gateway/
RUN dotnet publish fake-gateway/FakeGateway.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:de0ee358cdd672f7017a003bed21e9ac9ed48a27c922a59b18175b6e82fa7fee AS final
WORKDIR /app
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
# Not root: the non-root user the .NET images include, by its number
# (see DonHang.Api/Dockerfile).
USER $APP_UID
ENTRYPOINT ["dotnet", "FakeGateway.dll"]
