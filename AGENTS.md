This is a web application written using the Phoenix web framework.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


<!-- usage-rules-start -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages


<!-- phoenix:elixir-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it

<!-- phoenix:phoenix-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>

<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset

<!-- phoenix:liveview-end -->
<!-- verified_pubsub-start -->
## verified_pubsub usage
_Compile-time verified PubSub: verified routes, but for topics and events._

# Rules for VerifiedPubSub

VerifiedPubSub puts a manifest of topics and events over `Phoenix.PubSub`. Then a typo or
an unhandled event is a compile error. A project can move to it one topic at a time, so
raw `Phoenix.PubSub` code for other topics can stay next to it.

## Never bypass the manifest for a declared topic

The checks work only when each broadcast and subscription goes through the manifest. For
a topic that a manifest declares:

- Do not call `Phoenix.PubSub.broadcast/3`, `subscribe/2` or a similar function on it
  directly. Do not build its wire topic by hand. Use the macros below.
- Do not write `handle_info/2` clauses that match `%VerifiedPubSub.Message{}`. Use
  `handle_broadcast`.
- Do not send it a tuple like `{:adopted, pet}`. Broadcast a declared event with a payload
  map.

Leave raw `Phoenix.PubSub` code for undeclared topics as it is, unless the user asks you to
move it. To broadcast when the topic or the event is known only at runtime, call
`Phoenix.PubSub` directly.

## Declare topics in the manifest

```elixir
defmodule MyApp.Topics do
  use VerifiedPubSub.Manifest, pubsub: MyApp.PubSub

  topic :pets, ["owners", :owner_id, "pets"] do
    message :adopted do
      field :id, :string
      field :pet, MyApp.Pet
      field :species, :atom
      field :tricks, {:list, :string}
      field :nickname, :string, required: false
    end

    message :rehomed do
      field :id, :string
    end
  end

  topic :treats, ["owners", :owner_id, "treats"] do
    message :given do
      field :pet_id, :string
      field :from_owner_id, :string
      field :treat, :atom
    end
  end

  topic :system, ["system"] do
    message :alert do
      field :text, :string
    end
  end
end
```

- The segment list is the wire topic. A `:` joins its segments. A string is a literal
  segment, and an atom is a param. The params come from the segments. Never declare them
  separately.
- Field types: `:string`, `:integer`, `:float`, `:boolean`, `:atom`, `:map`, `:list`,
  `:any`, `{:list, type}`, or a struct module.
- With `required: false`, the key can be absent or `nil`. A field is required by default.
- `:pubsub` names a `Phoenix.PubSub` that the supervision tree starts.
- Document a topic, an event, or a field with `description`. Put it inside the block, as
  `description "..."`. When there is no block, use a keyword, as
  `message :rehomed, description: "..."`. Keyword options and a `do` block together do not
  compile.
- The manifest adds a `## Topics` section to its `@moduledoc`. The section lists each
  topic, event, and field. Do not list topics or events by hand in the `@moduledoc`.

## Broadcast

```elixir
defmodule MyApp.Pets do
  use VerifiedPubSub, manifest: MyApp.Topics

  def notify_adopted(pet) do
    broadcast!(:pets, %{owner_id: pet.owner_id}, :adopted, %{
      id: pet.id,
      pet: pet,
      species: pet.species,
      tricks: pet.tricks
    })
  end

  # Anyone can give a treat to anyone's pet. The broadcast goes to the pet's owner.
  def give_treat(pet, giver, treat) do
    broadcast!(:treats, %{owner_id: pet.owner_id}, :given, %{
      pet_id: pet.id,
      from_owner_id: giver.id,
      treat: treat
    })
  end
end
```

- The argument order is always `topic, params, event, payload`.
- A topic without params takes no params argument: `broadcast!(:system, :alert, %{text: "hi"})`.
- These are macros, so the topic and the event must be **literal atoms**. A pipe cannot
  pass a value into them, `&` cannot capture them, and `apply/3` cannot call them. A call
  site can build the params and the payload at runtime.
- The payload is a map of **exactly** the declared fields. Never pass a struct or an Ecto
  schema as the payload. Never add undeclared keys. Put a struct inside a field instead:
  `%{pet: pet}`.
- `broadcast!/4` raises on failure, and `broadcast/4` returns `:ok | {:error, term}`. Both
  raise `VerifiedPubSub.PayloadError` for a payload that is not valid.
- `broadcast_from!(self(), :pets, params, :adopted, payload)` skips the sender. Use it in a
  LiveView that writes to a topic and also subscribes to it. In a `Task`, an Oban job, or
  a context function, pass the pid of the process that started the request, not `self()`.
- `topic(:pets, %{owner_id: id})` returns the wire topic, when you need it.

## Subscribe and handle

```elixir
defmodule MyAppWeb.PetsLive do
  use MyAppWeb, :live_view
  use VerifiedPubSub.Subscriber, manifest: MyApp.Topics

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :ok = subscribe(:pets, %{owner_id: socket.assigns.owner.id})
    end

    {:ok, stream(socket, :pets, [])}
  end

  handle_broadcast :pets, :adopted, payload, socket do
    {:noreply, stream_insert(socket, :pets, payload.pet)}
  end

  handle_broadcast :pets, %{owner_id: owner_id}, :rehomed, %{id: id}, socket do
    {:noreply, assign(socket, :last_rehomed, {owner_id, id})}
  end
end
```

- `use VerifiedPubSub.Subscriber` also imports the broadcast macros. Do not also add
  `use VerifiedPubSub`.
- `handle_broadcast` is a macro at module level, not a `def`. Use it in GenServers and in
  LiveViews. It takes `topic, event, payload_pattern, state`. With params, it takes
  `topic, params_pattern, event, payload_pattern, state`, the same order as `broadcast!`.
- When many events have the same handler, give `handle_broadcast` a list of events in the
  place of the event: `handle_broadcast :pets, [:adopted, :renamed], payload, socket`. Do not
  write one identical clause for each event. A payload pattern must fit each event in the
  list. To read the event, match `%VerifiedPubSub.Message{event: event}`.
- Put the params right after the topic, never in the payload pattern. A params pattern can
  name a subset of the params.
- **The module must handle or ignore each event on each topic that it handles**, or the
  module does not compile. Ignore the events that the module does not need:
  `ignore_broadcast :pets, :rehomed` or `ignore_broadcast :pets, [:adopted, :rehomed]`.
- In a LiveView, subscribe only when `connected?(socket)`.
- Your own `handle_info/2` clauses still work next to `handle_broadcast`. They match after
  the generated clauses. So keep the existing clauses for topics that are not in the
  manifest.
- A module with handlers loses the default `handle_info/2`. When the process receives other
  messages, add your own catch-all `def handle_info(_msg, state), do: {:noreply, state}`
  after the handlers.
- When you match on literal param values, end with a clause that matches any value.
  Otherwise a message with a different value raises `FunctionClauseError`.

## Find where a topic is in use

- Before you grep for a topic or an event, run
  `mix verified_pubsub.topics TOPIC --format json`. It gives each `broadcast`, `handle_broadcast`,
  `ignore_broadcast`, and `subscribe` call of the topic, with its file and line.
- Add the event to get only that event: `mix verified_pubsub.topics pets adopted --format json`.
- Without a topic, the task prints each call site of each topic. Add `--summary` to get
  only the counts of each topic.
- Before you change or remove an event, read its call sites. Each broadcast and handler
  changes with it.
- The task runs in the current `MIX_ENV`. Run it with `MIX_ENV=test` to include the call
  sites in `test/support`. It does not read `.exs` files, so grep the tests too.
- A direct `Phoenix.PubSub` call does not show. Only the macros of VerifiedPubSub record a
  call site.

## Change the manifest

A new event on a topic stops the compile of each module that handles that topic. This is
intended. Fix each module that the compiler names with a `handle_broadcast` or an
`ignore_broadcast`. When you rename or remove an event, each broadcast and handler that uses
it stops the compile. Update all of them. Do not make the manifest less strict.

## Move an existing topic into the manifest

A topic in the manifest sends a different message over the wire. Subscribers receive a
`%VerifiedPubSub.Message{}`, not the term that the raw broadcast sent. So a raw subscriber
that you do not convert stops matching, with no error.

1. Search the whole project for the wire topic, including interpolated forms like
   `"owners:#{id}:pets"`. This finds each broadcaster and subscriber.
2. Declare the topic with segments that build the same wire topic. A `:` joins the
   segments. So you cannot declare a topic that uses another separator, such as
   `"pets/#{id}"`, as it is.
3. Convert each broadcaster and each subscriber **in the same change**. Never convert only
   one side.
4. Remove the old `handle_info/2` clauses for that topic. Keep the clauses for topics that
   you did not move yet.

## Fix the errors

| Error | Fix |
| --- | --- |
| `unknown topic` / `unknown event` | Use one of the names that the error lists, or declare it in the manifest. |
| `wrong params for topic` | Pass exactly the params that the error lists. It shows the missing or unexpected keys. |
| `invalid payload` (compile time) | Make the literal payload match the declared fields that the error shows. |
| `... declares no :x` in a `handle_broadcast` | The payload pattern names an undeclared key. When it is a param, move it right after the topic. |
| `subscribes to topics with events it does not account for` | Add `handle_broadcast` or `ignore_broadcast` for each event in the list. |
| `expected a literal atom for topic/event` | Write the atom inline. Do not use a variable or a module attribute. |
| `no manifest is in scope` | Add `use VerifiedPubSub, manifest: MyApp.Topics`. |
| `VerifiedPubSub.PayloadError` (runtime) | Build the payload with exactly the declared keys and types. |
| `VerifiedPubSub.TopicError` (runtime) | A param value was empty or had a `:` in it. |
| `KeyError` from a broadcast | A params map built at runtime does not have a param of the topic. |

<!-- verified_pubsub-end -->
<!-- usage-rules-end -->
