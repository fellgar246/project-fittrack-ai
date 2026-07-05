from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "fittrack-ai-api"
    version: str = "0.1.0"
    database_url: str
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60

    # AI provider settings. The fake provider is deterministic and requires no
    # credentials, so local development and tests never depend on Azure OpenAI.
    ai_provider: str = "fake"
    azure_openai_endpoint: str = ""
    azure_openai_api_key: str = ""
    azure_openai_deployment: str = ""
    azure_openai_api_version: str = ""
    azure_openai_timeout_seconds: int = 20
    azure_openai_max_retries: int = 2


settings = Settings()
