# Engineering Architecture Report: Lightweight Embedded Chatbot Integration with Adaptive Cards and Federated Single Sign-On
## Lightweight Client-Side Chat Frameworks
When designing a modern, high-performance embedded chat plugin, minimizing the client-side JavaScript footprint is critical to prevent degradation of the host website's page-load metrics. Heavy, enterprise-grade chat interfaces often carry massive dependency trees that inflate bundle sizes, slowing down DOM parsing and expanding the memory profile of the browser session. In the web ecosystem, several highly optimized, lightweight, and actively maintained React-compatible and open-source UI libraries provide the ideal building blocks for constructing customizable chatbot interfaces without the overhead of heavy proprietary SDKs.
The selection of a lightweight chat UI library depends heavily on the desired balance between architectural flexibility and out-of-the-box UI completeness. The library assistant-ui represents a prominent solution, adhering to a headless UI paradigm similar to Radix. By exposing unstyled, highly accessible primitive components—such as ThreadPrimitive, ComposerPrimitive, and MessagePrimitive—it delegates comprehensive design ownership to the engineering team while abstracting the complex, stateful mechanics of token-by-token message streaming, thread history persistence, and scroll anchoring. Conversely, chatcn represents an alternative that prioritizes ready-to-use aesthetic layouts. Built directly on top of shadcn/ui and styled using Tailwind CSS, chatcn delivers highly structured layout presets, including specialized floatable chat widgets, sidebar components with presence indicators, and rich media attachment grids.
Other specialized options include @llamaindex/chat-ui, which simplifies integration with streaming LLM backends via clean Tailwind configuration structures, and the highly modular react-chatbot-kit, which orchestrates conversational logic through a distinct three-tier setup of configuration objects, message parsers, and action providers. For deployment environments where a visual editor interface is used on the administrative backend, flowise-embed acts as a highly customizable wrapper that injects interactive chat bubbles or full-page interfaces directly connected to automated backend APIs.
The following table contrasts these prominent lightweight frontend solutions to guide engineering selection for custom embedded configurations:

| Technical Metric | assistant-ui | chatcn | @llamaindex/chat-ui | react-chatbot-kit | flowise-embed |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Architectural Philosophy** | Headless primitives with full UI composition | Copy-and-paste components for rapid styling | Composable high-level section containers | Structured, config-driven state wrapper | Standalone, script-initialized embed widget |
| **Primary Dependency Profile** | Zero styling opinions; pairs with any CSS engine | Radix UI primitives, Tailwind CSS | Tailwind CSS | Custom CSS / Styled Components | Tailwind CSS, Rollup runtime |
| **Streaming Integration** | Native hook lifecycle hooks (useChat, custom runtimes) | Custom streaming state handling | Direct Vercel AI SDK wrappers (useChat) | Manual callback orchestration for API calls | Built-in streaming listener protocol |
| **Typographical & Layout Control** | Complete; developer composes raw HTML nodes | High; direct access to source code of components | Medium; extended via custom React child nodes | Low; controlled via centralized config objects | Low; custom styling via overriding class rules |
| **Typical Compressed Package Footprint** | Extremely low due to headless tree-shaking | Low; only compile active copied component files | Low to Medium | Low; highly modular package | Medium; includes visual runtime dependencies |

Implementing a custom React plugin via assistant-ui yields the greatest architectural control, as it avoids locking the application into a specific CSS framework or preconfigured visual hierarchy, allowing developers to craft an interface that is indistinguishable from the host application's native design.
## Standalone Embedding Architecture and Style Isolation
Deploying a single, highly performant chat widget that executes seamlessly on arbitrary host web pages requires a deployment architecture that isolates the widget's internal environment from the host's script execution and CSS cascade. Without rigid isolation, global style resets, third-party frameworks like Bootstrap, or aggressive selectors (e.g., * { box-sizing: content-box !important; }) on the host page will distort the widget's visual layout.
### Dynamic Host Insertion and Shadow DOM Mounting
To establish a secure styling boundary, the widget must execute its initial mounting logic inside an isolated Shadow DOM v1 container. The bootstrap script, loaded asynchronously on the host page, executes a lifecycle sequence to inject the component tree:
First, the script instantiates a host container element inside the host's Light DOM, typically appending a <div> directly as a child of the document.body to establish a root stacking context. This host element is positioned using CSS position: fixed along with an exceptionally high z-index (e.g., 999999) to guarantee visibility above parent document layouts, avoiding clipping hazards unless a parent container invokes nested 3D transformations.
Second, the script attaches an open shadow root to this host container via element.attachShadow({ mode: 'open' }). This open boundary isolates the internal elements from the host document's querySelector queries while still permitting programmatic access through the host element's shadowRoot property.
Third, a dedicated React root is mounted inside a child node of the shadow root, initializing the virtual DOM tree completely within this isolated document fragment. The widget host container is configured with the all: initial CSS reset, which neutralizes inherited typographic and visibility styles that would otherwise bleed from the host page across the shadow boundary.
### Vite and Rollup IIFE Single-Bundle Strategy
For a seamless, non-technical installation process, the widget must compile into a single self-executing bundle. Utilizing a bundler like Rollup or Vite, all Javascript, React runtime components, and compiled styling classes are packed into an Immediately Invoked Function Expression (IIFE). This IIFE executes instantly upon script evaluation, eliminating the need to load adjacent external asset files.
The client website embeds the compiled file via a single, lightweight script tag:
```html
<script 
  async 
  defer 
  src="https://cdn.example.com/chatbot-widget.js" 
  data-client-key="enterprise_client_uuid"
></script>

```
This async loading approach ensures the main browser thread on the host website remains unblocked during initial page parsing.
### Style Injection via Constructable Stylesheets
A primary challenge of utilizing utility-first CSS frameworks like Tailwind CSS inside a Shadow DOM is that compiled stylesheet rules cannot penetrate the shadow host boundary. For Tailwind CSS (particularly Tailwind v4, which relies on native CSS custom properties configured in @theme structures), the compiled CSS rules must be made available within the shadow tree itself.
The modern standard to achieve this efficiently is the **Constructable Stylesheets API**. This API allows developers to programmatically create CSSStyleSheet objects directly in JavaScript, parse them once, and attach them to the shadow root using the adoptedStyleSheets array. This mechanism provides a significant performance advantage over inserting duplicate raw <style> elements, as the browser parses the compiled utility stylesheet exactly once in memory and shares the parsed reference across all instances of the components.
The following implementation displays the dynamic bootstrap execution code, importing Tailwind CSS as an inline string at build time via Vite's ?inline parameter, attaching the shadow root, constructing the style layer, and parsing the host configuration attributes:
```tsx
import { createRoot } from 'react-dom/client';
import { WidgetContainer } from './components/widget-container';
import tailwindStyleString from './styles/compiled-tailwind.css?inline'; // Build-time inline string import

function bootstrapWidget() {
  if (document.readyState !== 'loading') {
    executeMount();
  } else {
    document.addEventListener('DOMContentLoaded', executeMount);
  }
}

function executeMount() {
  try {
    const hostContainer = document.createElement('div');
    hostContainer.id = 'chatbot-widget-shadow-host';
    
    // Style the light-DOM host to float over host-page layouts
    hostContainer.style.position = 'fixed';
    hostContainer.style.bottom = '24px';
    hostContainer.style.right = '24px';
    hostContainer.style.zIndex = '2147483647'; // Max integer z-index to stay on top
    hostContainer.style.all = 'initial'; // Prevent host-page CSS resets from leaking in

    const shadowRoot = hostContainer.attachShadow({ mode: 'open' });
    const reactAppRoot = document.createElement('div');
    reactAppRoot.id = 'widget-application-root';
    shadowRoot.appendChild(reactAppRoot);

    // Style Isolation using Constructable Stylesheets
    if ('adoptedStyleSheets' in Document.prototype && 'replaceSync' in CSSStyleSheet.prototype) {
      const globalSheet = new CSSStyleSheet();
      globalSheet.replaceSync(tailwindStyleString);
      shadowRoot.adoptedStyleSheets = [globalSheet];
    } else {
      // Legacy fallback for browsers without Constructable Stylesheet support
      const styleTag = document.createElement('style');
      styleTag.textContent = tailwindStyleString;
      shadowRoot.appendChild(styleTag);
    }

    // Capture context variables directly off the script element attributes
    const currentScript = document.currentScript as HTMLScriptElement;
    const clientKey = currentScript?.getAttribute('data-client-key');
    if (!clientKey) {
      throw new Error('Chatbot execution terminated: missing data-client-key attribute.');
    }

    // Render the React application tree
    const root = createRoot(reactAppRoot);
    root.render(<WidgetContainer clientKey={clientKey} />);
    
    document.body.appendChild(hostContainer);
  } catch (error) {
    console.warn('Chatbot initialization encountered a critical error:', error);
  }
}

bootstrapWidget();

```
## Rendering Adaptive Cards inside Custom React Chat UIs
Adaptive Cards provide a schema-driven layout approach that allows backends to dispatch highly interactive visual cards using standard JSON payloads. Rather than embedding the heavy Microsoft Bot Framework Web Chat library to render these payloads, a custom React application can implement a lightweight wrapper around the official, standalone open-source JavaScript adaptivecards rendering SDK.
The standalone SDK (npm install adaptivecards) parses the schema, applies layout rules structured in a shared, cross-platform HostConfig configuration object, and instantiates native browser HTML elements automatically.
### Constructing the React Wrapper Component
Because the adaptivecards SDK returns standard browser DOM elements, it cannot be rendered directly as standard React Virtual DOM nodes. Instead, the React application must declare a container wrapper that utilizes a React reference (useRef) and executes the rendering process within a useEffect layout hook. Whenever the card's JSON schema properties change, the layout hook wipes the container and appends the newly computed card element.
The following React wrapper displays this rendering lifecycle, incorporating interactive submit handling, DirectLine content mapping, and markdown formatting:
```tsx
import { useEffect, useRef } from 'react';
import * as AdaptiveCards from 'adaptivecards';
import DOMPurify from 'dompurify';
import { marked } from 'marked';

// Centralized style mapping designed to match the application's aesthetic token values
const widgetHostConfig = new AdaptiveCards.HostConfig({
  fontFamily: "Inter, system-ui, -apple-system, sans-serif",
  supportsInteractivity: true,
  fontSizes: { small: 12, default: 14, medium: 16, large: 18, extraLarge: 22 },
  fontWeights: { lighter: 200, default: 400, bolder: 700 },
  containerStyles: {
    default: { backgroundColor: "#ffffff", foregroundColor: "#1f2937" },
    emphasis: { backgroundColor: "#f3f4f6", foregroundColor: "#111827" }
  },
  actions: {
    actionsOrientation: AdaptiveCards.ActionsOrientation.Horizontal,
    actionAlignment: AdaptiveCards.ActionAlignment.Stretch,
    maxActions: 4
  }
});

interface AdaptiveCardWrapperProps {
  cardPayload: object;
  onCardSubmit: (data: object) => void;
}

export function AdaptiveCardWrapper({ cardPayload, onCardSubmit }: AdaptiveCardWrapperProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    // Flush previous element tree to prevent rendering duplicates on re-render
    containerRef.current.innerHTML = '';

    // DirectLine Mapping: Normalizes custom content schemas
    let normalizedPayload = { ...cardPayload } as any;
    if (normalizedPayload.contentType === 'application/vnd.microsoft.card.custom') {
      normalizedPayload.contentType = 'application/vnd.microsoft.card.adaptive';
    }

    const adaptiveCard = new AdaptiveCards.AdaptiveCard();
    adaptiveCard.hostConfig = widgetHostConfig;

    // Secure Markdown Processing Protocol (CWE-79 Remediation)
    AdaptiveCards.AdaptiveCard.onProcessMarkdown = (text, result) => {
      try {
        const rawCompiledHtml = marked.parse(text, { async: false }) as string;
        // Strip out dangerous event attributes and script insertions
        result.outputHtml = DOMPurify.sanitize(rawCompiledHtml);
        result.didProcess = true; // Signals the SDK to render as HTML rather than raw text
      } catch (error) {
        console.error('Markdown processing failed:', error);
        result.didProcess = false;
      }
    };

    // Form submission callback handling
    adaptiveCard.onExecuteAction = (action) => {
      if (action instanceof AdaptiveCards.SubmitAction) {
        // Collect all input elements in the card
        const compiledInputs = action.data || {};
        onCardSubmit(compiledInputs);

        // Terminate interactivity to avoid double-submit or historical edits
        if (containerRef.current) {
          disableCardInputsAndButtons(containerRef.current);
        }
      }
    };

    try {
      adaptiveCard.parse(normalizedPayload);
      const nativeCardElement = adaptiveCard.render();
      if (nativeCardElement) {
        containerRef.current.appendChild(nativeCardElement);
      }
    } catch (parseError) {
      console.error('Adaptive Card parsing exception:', parseError);
      containerRef.current.textContent = 'Error rendering dynamic content.';
    }
  }, [cardPayload, onCardSubmit]);

  return <div ref={containerRef} className="adaptive-card-container w-full bg-white shadow-sm border border-gray-100 rounded-lg overflow-hidden" />;
}

/**
 * Traverses the card DOM tree, disabling input elements and buttons
 * to prevent double submissions and state desynchronization.
 */
function disableCardInputsAndButtons(cardNode: HTMLElement) {
  const interactiveElements = cardNode.querySelectorAll<HTMLButtonElement | HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>(
    'button, input, select, textarea'
  );

  interactiveElements.forEach((element) => {
    element.setAttribute('disabled', 'true');
    element.style.opacity = '0.5';
    element.style.cursor = 'not-allowed';
    element.style.pointerEvents = 'none';
  });

  // Block clicks at the container boundary to prevent event propagation
  cardNode.addEventListener(
    'click',
    (event) => {
      event.preventDefault();
      event.stopPropagation();
    },
    { capture: true }
  );
}

```
## Enterprise SSO Integration and Secure Token Exchange
Identifying and authorizing users inside a third-party embedded widget must be handled securely without duplicating credentials or compromising security boundaries. The widget must leverage the parent website's active Single Sign-On (SSO) session to obtain a valid identity context.
### Client-Side Federated Authentication Protocol
To identify and authorize users within an embedded context, the system delegates user authentication directly to the host website, which acts as the trusted first-party domain. When a user loads the host website, the parent page orchestrates authentication against its centralized Identity Provider (such as Microsoft Entra ID, Keycloak, or Okta) using its primary client library (e.g., Microsoft Authentication Library - MSAL).
Once authenticated, the host website must securely provide identity context to the embedded chatbot widget. This is achieved using a **Federated Token Exchange Protocol**:
```text
+---------------+           +---------------------+           +-----------------+
|               |           |                     |           |                 |
|  Host Website |           |    Chatbot Widget   |           | Chatbot Backend |
|     (SPA)     |           |       (Client)      |           |     (Server)    |
|               |           |                     |           |                 |
+-------+-------+           +----------+----------+           +--------+--------+
        |                              |                               |
        |  1. Request Localized Token   |                               |
        |======------------------------>|                               |
        |                              |                               |
        |  2. Register JWT Provider    |                               |
        |----------------------------->|                               |
        |                              |                               |
        |  3. Invoke setAuthTokenProv  |                               |
        |  4. Resolve Short-Lived JWT  |                               |
        |<-----------------------------|                               |
        |                              |                               |
        |                              |  5. Initiate Connection        |
        |                              |=====------------------------->|
        |                              |  6. JWT in Auth Header        |
        |                              |                               |
        |                              |                               |  7. Verify RSA256
        |                              |                               |  using Host JWKS
        |                              |                               |  endpoint
        |                              |                               |---------\
        |                              |                               |         |
        |                              |                               |<--------/
        |                              |                               |
        |                              |  8. Connection Authorized     |
        |                              |<------------------------------|

```
1. **JWT Generation:** The host website’s OIDC client fetches a specialized, short-lived JSON Web Token (JWT) from its token generation server. This JWT carries identity claims (such as sub, iss, iat, and exp) and a payload representing serialized user attributes (e.g., lwicontexts containing variables for custom routing or agent assignment).
2. **Dynamic Token Registration Callback:** The host website registers a client-side provider callback on the global scope after the widget is ready. On load, the widget triggers this callback, which resolves the JWT.
3. **Public Key Verification (RSA256):** The chatbot widget client forwards this JWT to the chatbot backend server in the Authorization: Bearer <token> header. The chatbot backend verifies the token using the public key retrieved dynamically from the host’s JWKS (JSON Web Key Set) endpoint. This verification uses the RSA256 asymmetric cryptographic algorithm, ensuring that the backend can validate the token's signature without requiring access to the private signing key.
The structure of the JSON Web Token payload required for secure identity propagation is detailed below:

| JWT Claim Key | Data Type | Requirement | Technical Definition and Practical Implications |
|---|---|---|---|
| **iss** | String | Mandatory | **Issuer:** Identifies the principal authority that generated and signed the token, allowing the backend to match the token against trusted SSO providers. |
| **sub** | String (GUID) | Mandatory | **Subject:** Represents the unique identifier of the user (e.g., account or contact ID). The backend maps this claim directly to user records in the target database. |
| **iat** | Integer (Epoch) | Mandatory | **Issued At:** The exact Unix timestamp indicating when the JWT was generated, establishing a baseline for token age validation. |
| **exp** | Integer (Epoch) | Mandatory | **Expiration Time:** Timestamp defining token validity. To minimize security risks if intercepted, lifetimes are restricted to short intervals (T_{expiry} \le 10 \text{ minutes}). |
| **lwicontexts** | Object (JSON) | Optional | **Serialized Custom Context:** A key-value collection of primitive attributes. These values are used by routing and agent allocation engines to prioritize or assign conversations based on user tier or history. |

### Mitigating Client-Side Security Threats (XSS & Origin Validation)
To protect sensitive authentication tokens within the browser environment, the architecture must implement strict security controls:
First, the embedded widget must **never persist tokens inside localStorage or sessionStorage**. Storage APIs are fully readable by any Javascript execution thread running in the same origin context. If an attacker successfully executes a Cross-Site Scripting (XSS) exploit, runs a malicious browser extension, or compromises a third-party npm dependency, they can exfiltrate the stored token and gain unauthorized access. The access token must be held **strictly in-memory** using scoped JavaScript variables or state frameworks.
Second, when utilizing cross-origin messaging (such as window.postMessage between an iframe and the parent frame), the receiver must **always validate the origin** of the sender. Using wildcard origin selectors ("*") on the transmission side is strictly prohibited, as it allows arbitrary domains to capture the payload. The receiver must implement a strict origin match check, rejecting any message whose event.origin does not match the explicit URL of the trusted first-party host.
### Safari ITP and Third-Party Cookie Bypass
Modern tracking restrictions, such as Apple Safari's Intelligent Tracking Prevention (ITP) and Google Chrome's third-party cookie restrictions, prevent cross-origin embedded widgets from utilizing silent iframe refreshes or reading third-party cookies. When loaded inside an iframe or cross-origin script context, any attempt to read state from a domain-associated cookie is blocked by the browser.
To resolve Safari ITP compatibility, the chatbot widget architecture must utilize a **Parent-Mediated Token Exchange Protocol**:
First, the widget relies solely on short-lived access tokens stored in-memory.
Second, when the access token is near expiration, the widget initiates a request by sending a targeted postMessage command up to the parent host website.
Third, because the parent host operates in a first-party context, it does not suffer from third-party cookie restrictions. The parent context securely initiates a silent session fetch or hits its first-party token endpoint to obtain a fresh access token from the Identity Provider.
Fourth, once acquired, the parent host posts the fresh token back down to the widget's secure message listener, which updates its in-memory reference.
This protocol allows the widget to safely maintain authorized sessions across all major browsers, avoiding cookie blocking while keeping token lifetimes short to minimize security exposure.
## Architectural Synthesis and Security Checklist
The successful execution of a lightweight, highly isolated, and securely authenticated chatbot widget relies on enforcing structural boundaries across the entire rendering and authentication life cycle.
The final system design is summarized in the following engineering architectural workflow diagram:
```text
HOST DOM (LIGHT DOM)
┌────────────────────────────────────────────────────────────────────────┐
│  Host Page CSS: body { font-size: 10px; button { background: red; } }  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Chatbot Host Node (all: initial)                                 │  │
│  │   SHADOW DOM BOUNDARY                                            │  │
│  │   ┌──────────────────────────────────────────────────────────┐   │  │
│  │   │ CSSStyleSheet (adoptedStyleSheets)                       │   │  │
│  │   │   :host { font-size: 16px; button { background: blue; } }│   │  │
│  │   │ ├────────────────────────────────────────────────────────┤   │  │
│  │   │ │ React Application Tree                                 │   │  │
│  │   │ │                                                        │   │  │
│  │   │ │  ┌───────────────┐        ┌─────────────────────────┐  │   │  │
│  │   │ │  │               │        │ Adaptive Card Container │  │   │  │
│  │   │ │  │ Chat History  │        │   ┌───────────────────┐ │  │   │  │
│  │   │ │  │    (Prose)    │        │   │ onProcessMarkdown │ │  │   │  │
│  │   │ │  │               │        │   │ (marked+DOMPurify)│ │  │   │  │
│  │   │ │  └───────────────┘        │   │ [CWE-79 Sanitized]│ │  │   │  │
│  │   │ │                           │   └───────────────────┘ │  │   │  │
│  │   │ │                           │   ┌───────────────────┐ │  │   │  │
│  │   │ │                           │   │  Input Disabling  │ │  │   │  │
│  │   │ │                           │   │  [Transience Lock]│ │  │   │  │
│  │   │ │                           │   └───────────────────┘ │  │   │  │
│  │   │ │                           └─────────────────────────┘  │   │  │
│  │   │ └────────────────────────────────────────────────────────┘   │  │
│  │   └──────────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘

```
This structural separation ensures that global host styles—such as the red button backgrounds or scaled font sizes—are blocked at the shadow boundary, allowing the widget to render consistently with its own scoped styles. Concurrently, markdown content is compiled and sanitized before insertion, protecting the widget from script injections and DOM-based exploits.
By combining headless React rendering, constructable style isolation, safe markdown processing, and federated, parent-mediated SSO token verification, developers can deliver a high-performance chat interface. This unified architecture provides strict isolation and security controls while maintaining a lightweight client-side footprint.
