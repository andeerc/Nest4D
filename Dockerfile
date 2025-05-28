FROM scottyhardy/docker-wine:stable-7.0-20220213

# Copia o executável para o diretório padrão
COPY Nest4DSample.exe /home/wineuser/Nest4DSample.exe

# Define o diretório de trabalho
WORKDIR /home/wineuser

EXPOSE 3030

# Comando padrão para executar quando o contêiner iniciar
CMD ["wine", "Nest4DSample.exe"]
