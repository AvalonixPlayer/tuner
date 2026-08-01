FROM ghcr.io/cirruslabs/flutter:3.41.9

WORKDIR /app

COPY pubspec.* ./

RUN flutter pub get

COPY . .

CMD ["flutter", "build", "apk", "--release"]
