# lesson: backend.l3.payments-service
# The Payments service's own image, built like the api's (see
# DonHang.Api/Dockerfile): the SDK builds, a smaller runtime image runs.
# Only the two projects it uses are copied in.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY global.json Directory.Packages.props ./
COPY DonHang.Messaging/DonHang.Messaging.csproj DonHang.Messaging/
COPY DonHang.Payments/DonHang.Payments.csproj DonHang.Payments/
RUN dotnet restore DonHang.Payments/DonHang.Payments.csproj

COPY DonHang.Messaging/ DonHang.Messaging/
COPY DonHang.Payments/ DonHang.Payments/
RUN dotnet publish DonHang.Payments/DonHang.Payments.csproj -c Release -o /app --no-restore

# `--target migrate`: the migration bundle for donhang_payments. Run
# against a database that does not exist yet, it creates it first.
FROM build AS bundle
COPY .config/dotnet-tools.json .config/
RUN dotnet tool restore \
    && dotnet ef migrations bundle --project DonHang.Payments --configuration Release --output /bundle/efbundle

# aspnet, not runtime as for the api's bundle: this is a web project, and
# its bundle asks for the ASP.NET Core framework even though it never serves.
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS migrate
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /migrate
COPY --from=bundle /bundle/efbundle .
ENTRYPOINT ["./efbundle"]

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "DonHang.Payments.dll"]
