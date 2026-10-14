# lesson: backend.l3.payments-service
# The Payments service's own image, built like the api's (see
# DonHang.Api/Dockerfile): the SDK builds, a smaller runtime image runs.
# Only the two projects it uses are copied in.
FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:e70cdb7f80b0348f5cb85f19a8f670fca061f033d57eed12fa003d58b0e06317 AS build
WORKDIR /src

COPY global.json Directory.Packages.props Directory.Build.props ./
COPY DonHang.Messaging/DonHang.Messaging.csproj DonHang.Messaging/packages.lock.json DonHang.Messaging/
COPY DonHang.Payments/DonHang.Payments.csproj DonHang.Payments/packages.lock.json DonHang.Payments/
RUN dotnet restore DonHang.Payments/DonHang.Payments.csproj --locked-mode

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
FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:d5633778c754e89a386882eddf8dbee6942447a8a4b8267c19cf1e1158d0b0ac AS migrate
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /migrate
COPY --from=bundle /bundle/efbundle .
# Not root either: the same non-root user as the service's image below.
USER $APP_UID
ENTRYPOINT ["./efbundle"]

FROM mcr.microsoft.com/dotnet/aspnet:10.0@sha256:d5633778c754e89a386882eddf8dbee6942447a8a4b8267c19cf1e1158d0b0ac AS final
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
# Not root: the non-root user the .NET images include, by its number
# (see DonHang.Api/Dockerfile).
USER $APP_UID
ENTRYPOINT ["dotnet", "DonHang.Payments.dll"]
