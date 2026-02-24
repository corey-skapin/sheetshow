FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/SheetShow.Api/SheetShow.Api.csproj", "src/SheetShow.Api/"]
COPY ["src/SheetShow.Infrastructure/SheetShow.Infrastructure.csproj", "src/SheetShow.Infrastructure/"]
COPY ["src/SheetShow.Core/SheetShow.Core.csproj", "src/SheetShow.Core/"]
RUN dotnet restore "src/SheetShow.Api/SheetShow.Api.csproj"
COPY . .
WORKDIR "/src/src/SheetShow.Api"
RUN dotnet build "SheetShow.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "SheetShow.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "SheetShow.Api.dll"]
