<x-mail::message>
# Introduction

{{ $lenderName }} asked to see your score. Open the app to approve or decline. If you don’t recognise them, decline.

<x-mail::button :url="''">
Button Text
</x-mail::button>

Thanks,<br>
{{ config('app.name') }}
</x-mail::message>
