from litellm.integrations.custom_logger import CustomLogger
import litellm
from rich import print


# This file includes the custom callbacks for LiteLLM Proxy
# Once defined, these can be passed in proxy_config.yaml
class MyCustomHandler(CustomLogger):

    def log_pre_api_call(self, model, messages, kwargs):
        print("[bold green]Pre-API Call[/bold green]")

    def log_post_api_call(self, kwargs, response_obj, start_time, end_time):
        print("[bold blue]Post-API Call[/bold blue]")

    def log_stream_event(self, kwargs, response_obj, start_time, end_time):
        print("[bold cyan]On Stream[/bold cyan]")

    def log_success_event(self, kwargs, response_obj, start_time, end_time):
        print("[bold magenta]On Success[/bold magenta]")

    def log_failure_event(self, kwargs, response_obj, start_time, end_time):
        print("[bold red]On Failure[/bold red]")

    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        print("[bold green]On Async Success![/bold green]")
        # log: key, user, model, prompt, response, tokens, cost
        # Access kwargs passed to litellm.completion()
        model = kwargs.get("model", None)
        messages = kwargs.get("messages", None)
        user = kwargs.get("user", None)

        # Access litellm_params passed to litellm.completion(), example access `metadata`
        litellm_params = kwargs.get("litellm_params", {})
        metadata = litellm_params.get("metadata", {})  # headers passed to LiteLLM proxy, can be found here

        # Calculate cost using  litellm.completion_cost()
        cost = litellm.completion_cost(completion_response=response_obj)
        response = response_obj
        # tokens used in response
        usage = response_obj["usage"]

        # Format messages as markdown
        formatted_messages = "\n".join(
            [f"- **Role**: {msg['role']}, **Content**: {msg['content']}" for msg in messages])

        print(f"""
            [bold yellow]Model:[/bold yellow] {model}
            [bold yellow]Messages:[/bold yellow]
            {formatted_messages}
            [bold yellow]User:[/bold yellow] {user}
            [bold yellow]Usage:[/bold yellow] {usage}
            [bold yellow]Cost:[/bold yellow] {cost}
            [bold yellow]Response:[/bold yellow] {response}
            [bold yellow]Proxy Metadata:[/bold yellow] {metadata}
        """)
        return

    async def async_log_failure_event(self, kwargs, response_obj, start_time, end_time):
        try:
            print("[bold red]On Async Failure![/bold red]")
            print(f"[bold yellow]kwargs:[/bold yellow] {kwargs}")
            # Access kwargs passed to litellm.completion()
            model = kwargs.get("model", None)
            messages = kwargs.get("messages", None)
            user = kwargs.get("user", None)

            # Access litellm_params passed to litellm.completion(), example access `metadata`
            litellm_params = kwargs.get("litellm_params", {})
            metadata = litellm_params.get("metadata", {})  # headers passed to LiteLLM proxy, can be found here

            # Acess Exceptions & Traceback
            exception_event = kwargs.get("exception", None)
            traceback_event = kwargs.get("traceback_exception", None)

            # Calculate cost using  litellm.completion_cost()
            cost = litellm.completion_cost(completion_response=response_obj)
            print("now checking response obj")

            # Format messages as markdown
            formatted_messages = "\n".join(
                [f"- **Role**: {msg['role']}, **Content**: {msg['content']}" for msg in messages])

            print(f"""
                    [bold yellow]Model:[/bold yellow] {model}
                    [bold yellow]Messages:[/bold yellow]
                    {formatted_messages}
                    [bold yellow]User:[/bold yellow] {user}
                    [bold yellow]Cost:[/bold yellow] {cost}
                    [bold yellow]Response:[/bold yellow] {response_obj}
                    [bold yellow]Proxy Metadata:[/bold yellow] {metadata}
                    [bold yellow]Exception:[/bold yellow] {exception_event}
                    [bold yellow]Traceback:[/bold yellow] {traceback_event}
                """)
        except Exception as e:
            print(f"[bold red]Exception:[/bold red] {e}")


proxy_handler_instance = MyCustomHandler()

# Set litellm.callbacks = [proxy_handler_instance] on the proxy
# need to set litellm.callbacks = [proxy_handler_instance] # on the proxy
